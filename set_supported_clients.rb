require 'redis'
require 'json'

@redis = Redis.new(url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{ENV['REDIS_DB']}")

supported_clients = [
    "albiondata-client/0.1.31"
]

@redis.set('supported_clients', supported_clients.to_json)
