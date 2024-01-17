require 'redis'
require 'json'

file_name = ARGV[0]

@redis = Redis.new(url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{ENV['REDIS_DB']}")

@redis.del('bad_ips')
ips = File.open(file_name, 'r').read.split("\n")
@redis.sadd('bad_ips', ips)
