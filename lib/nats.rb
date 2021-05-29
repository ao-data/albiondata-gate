require 'nats/io/client'

class NATSForwarder
  LOGGER = Logger.new(STDOUT)
  
  @@q = {}
  TOPICS.each { |t| @@q[t] = [] }
  @@nats = NATS::IO::Client.new

  def self.q; @@q; end

  def self.start
    Thread.new do
      @@nats.connect(NATS_URI, {verbose: true})
      while @@nats.connected?
        sleep 5
        TOPICS.each do |topic|
          next if @@q[topic].count < 1
          LOGGER.info("NATS") { "Forwarding Q of: #{topic} (#{@@q[topic].count} msgs)"  }
          @@q[topic].each do |msg|
            @@nats.publish(topic, msg.to_json)
            @@q[topic].delete(msg)
          end
        end
      end
    end
  end
end
