#!/usr/bin/env ruby
require 'logger'
require 'pry'
require 'sinatra'
require 'securerandom'
require 'digest/sha2'
require 'rack/throttle'
require 'redis'

STDOUT.sync = true
LOGGER = Logger.new(STDOUT)

if File.exist?(__dir__ + "/config.local.rb")
  require_relative 'config.local'
else
  require_relative 'config'
end

require_relative 'lib/nats'
require_relative 'lib/pow-cache'
require_relative 'lib/abuseipdb'

NATSForwarder.start

class AODGate < Sinatra::Base
  configure do
    set :sessions, false
    set :logging, true
    set :show_exceptions, true
    set :run, false
    set bind: "0.0.0.0"
    set port: ENV['POW_PORT']
    set server: "puma"
  end

  def initialize
    super
    @redis = Redis.new(url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}/#{ENV['REDIS_DB']}")
  end

  use Rack::Throttle::Minute, :max => REQUEST_LIMIT[:per_minute]
  use Rack::Throttle::Hourly, :max => REQUEST_LIMIT[:per_hour]
  use Rack::Throttle::Daily, :max => REQUEST_LIMIT[:per_day]

  before do
  end

  get '/pow' do
    challange = { wanted: SecureRandom.hex(POW_RANDOMNESS).unpack("B*")[0][0..POW_DIFFICULITY-1], key: SecureRandom.hex(POW_RANDOMNESS) }
    @redis.set(challange[:key], {wanted: challange[:wanted]}.to_json, ex: ENV['POW_EXPIRE_SECONDS'].to_i)
    return challange.to_json
  end

  post '/pow/:topic' do
    supported_clients_json = @redis.get('supported_clients')
    if supported_clients_json
      supported_clients = JSON.parse(supported_clients_json)
      halt(905, "Unsupported data client.") if !supported_clients.empty? && !supported_clients.include?(request.env['HTTP_USER_AGENT'])
    end

    halt 404 unless TOPICS.include?(params[:topic])
    pow_json = @redis.get(params[:key])
    @redis.del(params[:key])
    halt(902, "Pow not handed") unless pow_json # This pow was never requested or has expired
    pow = JSON.parse(pow_json)

    halt(903, "Pow not solved correctly") unless Digest::SHA2.hexdigest("aod^" + params[:solution] + "^" + params[:key]).unpack("B*")[0].start_with?(pow['wanted'])
    halt(904, "Payload too large") unless params[:natsmsg].bytesize <= NATS_PAYLOAD_MAX

    begin
      data = JSON.parse(params[:natsmsg])
    rescue
      halt(901, "Invalid JSON data")
    end

    if params[:topic] == "marketorders.ingest" && data['Orders'].count > 50
      LOGGER.warn("Error 904, Too Much Data. ip: #{request.ip}, topic: marketorders.ingest, order count: #{data['Orders'].count}")
      halt(904, "Too much data")
    end

    if params[:topic] == "goldprices.ingest" && data['Prices'].count > 673
      LOGGER.warn("Error 904, Too Much Data. ip: #{request.ip}, topic: goldprices.ingest, order count: #{data['Prices'].count}")
      halt(904, "Too much data")
    end

    if params[:topic] == "markethistories.ingest"
      failed = false

      failed = true if data['Timescale'] == 0 && data['MarketHistories'].count > 25
      failed = true if data['Timescale'] == 1 && data['MarketHistories'].count > 29
      failed = true if data['Timescale'] == 2 && data['MarketHistories'].count > 113


      if failed == true
        LOGGER.warn("Error 904, Too Much Data. ip: #{request.ip}, topic: markethistories.ingest, Timescale: #{data['Timescale']}, MarketHistories count: #{data['MarketHistories'].count}")
        halt(904, "Too much data")
      end
    end

    # check if ip is a known bad ip
    ipdb = Ipdb.new(@redis)
    is_ip_good = ipdb.check_ip(request.ip)

    log_params = params.merge({request_ip: request.ip, user_agent: request.env['HTTP_USER_AGENT']})
    if is_ip_good == true
      NATSForwarder.forward(params[:topic], data)
      LOGGER.info(log_params.to_json) if ENV['DEBUG'] == "true"
    else
      LOGGER.info(log_params.merge({bad_ip: true}).to_json) if ENV['DEBUG'] == "true"
    end
    $POW_MUTEX.synchronize { $POWS.delete(params[:key]) }
    halt(200, "OK")
  end
end

binding.pry if $0 == "pry"
LOGGER.info("Starting server...")
