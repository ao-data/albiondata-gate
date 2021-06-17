require 'nats/io/client'

class NATSForwarder
  LOGGER = Logger.new(STDOUT)
  @@nats = NATS::IO::Client.new

  
  def self.start
    @@nats.connect(NATS_URI, {verbose: true}) if ENV['ENABLE_NATS'] == "1"
  end


  def self.forward(topic, msg)
    @@nats.publish(topic, msg.to_json) if ENV['ENABLE_NATS'] == "1"
  end

end
