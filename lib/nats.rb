require 'nats/io/client'

class NATSForwarder
  LOGGER = Logger.new(STDOUT)

  @@q = {}
  TOPICS.each { |t| @@q[t] = [] }
  @@nats = NATS::IO::Client.new

  def self.q; @@q; end
  def self.nats; @@nats; end

  def self.forward(topic, msg)
    @@nats.publish(topic, msg.to_json)
  end

  def self.start
    @@nats.connect(NATS_URI, {verbose: true})
  end
end
