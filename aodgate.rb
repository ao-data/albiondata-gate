#!/usr/bin/env ruby
require 'logger'
require 'pry'
require 'sinatra'
require 'securerandom'
require 'digest/sha2'
require 'rack/throttle'

STDOUT.sync = true
LOGGER = Logger.new(STDOUT)

if File.exist?(__dir__ + "/config.local.rb")
  require_relative 'config.local'
else
  require_relative 'config'
end

require_relative 'lib/nats'
require_relative 'lib/pow-cache'

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

  use Rack::Throttle::Minute, :max => REQUEST_LIMIT[:per_minute]
  use Rack::Throttle::Hourly, :max => REQUEST_LIMIT[:per_hour]
  use Rack::Throttle::Daily, :max => REQUEST_LIMIT[:per_day]

  before do
  end

  get '/pow' do
    challange = { wanted: SecureRandom.hex(POW_RANDOMNESS).unpack("B*")[0][0..POW_DIFFICULITY-1], key: SecureRandom.hex(POW_RANDOMNESS) }
    $POW_MUTEX.synchronize { $POWS[challange[:key]] = {wanted: challange[:wanted]} }
    return challange.to_json
  end

  post '/pow/:topic' do
    halt 404 unless TOPICS.include?(params[:topic])
    pow = $POWS[params[:key]]
    halt(902, "Pow not handed") unless pow # This pow was never requested
    halt(903, "Pow not solved correctly") unless Digest::SHA2.hexdigest("aod^" + params[:solution] + "^" + params[:key]).unpack("B*")[0].start_with?(pow[:wanted])

    begin
      data = JSON.parse(params[:natsmsg])
    rescue
      halt(901, "Invalid JSON data")
    end

    halt(904, "Too much data") if params[:topic] == "marketorders.ingest" and data['Orders'].count > 50
    halt(904, "Too much data") if params[:topic] == "goldprices.ingest" && data['Prices'].count > 673

    if params[:topic] == "markethistories.ingest"
      halt(904, "Too much data") if data['Timescale'] == 0 && data['MarketHistories'].count > 24
      halt(904, "Too much data") if data['Timescale'] == 1 && data['MarketHistories'].count > 29
      halt(904, "Too much data") if data['Timescale'] == 2 && data['MarketHistories'].count > 113
    end

    NATSForwarder.forward(params[:topic], data)
    $POW_MUTEX.synchronize { $POWS.delete(params[:key]) }
    halt(200, "OK")

  end
end

binding.pry if $0 == "pry"
LOGGER.info("Starting server...")
