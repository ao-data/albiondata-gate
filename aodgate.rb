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
    set port: 4223
    set server: "puma"
  end

  use Rack::Throttle::Minute, :max => REQUEST_LIMIT[:per_minute]
  use Rack::Throttle::Hourly, :max => REQUEST_LIMIT[:per_hour]
  use Rack::Throttle::Daily, :max => REQUEST_LIMIT[:per_day]

  before do
  end

  get '/pow' do
    challange = { wanted: SecureRandom.hex(POW_RANDOMNESS).unpack("B*")[0][0..POW_DIFFICULITY-1], key: SecureRandom.hex(POW_RANDOMNESS) }
    $POW_MUTEX.synchronize { $POWS[challange[:key]] = {wanted: challange[:wanted], solved: false} }
    return challange.to_json
  end

  post '/pow' do
    pow = $POWS[params[:key]]
    halt(902, "Pow not handed") unless pow # This pow was never requested
    halt(903, "Pow not solved correctly") unless Digest::SHA2.hexdigest("aod^" + params[:solution] + "^" + params[:key]).unpack("B*")[0].start_with?(pow[:wanted])
    $POW_MUTEX.synchronize { pow[:solved] = true }
    halt(200, "OK")
  end

  post '/:topic/:pow' do
    halt 404 unless TOPICS.include?(params[:topic])
    pow = $POWS[params[:pow]]
    halt(904, "Pow not solved") unless pow && pow[:solved]
    begin
      data = JSON.parse(request.body.read)
    rescue
      halt(901, "Invalid JSON data")
    end
    NATSForwarder.forward([params[:topic]], data)
    $POW_MUTEX.synchronize { $POWS.delete(params["pow"]) }
    halt(200, "OK")
  end
end

binding.pry if $0 == "pry"
LOGGER.info("Starting server...")
