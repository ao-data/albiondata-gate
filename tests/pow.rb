require 'net/http'
require 'json'
require 'digest/sha2'
require 'securerandom'

def run_test(big_tiems = false, marketorders = true, goldprices = false, markethistories = false, supportedclient = true)
  uri = URI.parse(ARGV[0])
  long_test = ARGV[1] || "0"

  # Retrieve a pow
  # GET request to http://albion-online-data.com:4223 returns JSON data:
  # {"wanted":"01100001001100110110010100110001001100","key":"4e8d1a"}
  response = Net::HTTP.get(uri.host, '/pow', uri.port)
  pow = JSON.parse(response)

  # Solve the pow
  # The client has to guess the solution by generation randomness
  # It can then check if the solution is correct itself by hashing: 
  # SHA2(aod^ + SHA2(solution) + ^ + *key*)
  # The result has to start with the bits of *wanted* to be correct

  start = Time.now
  solution = ""
  until (Digest::SHA2.hexdigest("aod^" + solution + "^" + pow['key'])).unpack("B*")[0].start_with?(pow['wanted']) do
    solution = Digest::SHA2.hexdigest(SecureRandom.bytes(128))
  end

  sleep 15 if long_test == "1"

  puts "pow solved after #{Time.now - start} seconds"
  puts solution

  topic = "marketorders.ingest"
  topic = "goldprices.ingest" if goldprices == true
  topic = "markethistories.ingest" if markethistories == true
  
  nats_obj_name = "Orders"
  nats_obj_name = "Prices" if goldprices == true
  nats_obj_name = "MarketHistories" if markethistories == true

  # Send a POST to the http server cotaining the topic and pow key/solution
  items = [{"foo": "bar"}]
  if big_tiems == true
    1100.times do |x|
      items.append({"foo#{x}": "bar"})
    end
  end

  msg = {natsmsg: {"#{nats_obj_name}": items}.to_json, 'key': pow['key'], 'solution': solution}

  if markethistories == true
    msg = {natsmsg: {"Timescale":0, "#{nats_obj_name}": items}.to_json, 'key': pow['key'], 'solution': solution}
  end

  headers  = {"User-Agent" => (supportedclient == true ? 'albiondata-client/0.1.31' : 'some_other_client')}
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new("/pow/#{topic}", headers)
  request.add_field('Content-Type', 'application/x-www-form-urlencoded; charset=utf-8')
  request.body = URI.encode_www_form(msg)
  response = http.request(request)
  puts "Server says: #{response.code} #{response.body}"
  puts "------------------------------------------------"
end

puts "------------------------------------------------"

# default test
puts "*Expect 200"
run_test()

# big marketorders
puts "*Expect 904"
run_test(true)

# big markethistories
puts "*Expect 904"
run_test(true, false, false, true)

# big goldprices
puts "*Expect 904"
run_test(true, false, true)

# supported user agents
puts "*Expect 905"
run_test(true, false, false, false, false)

#############################################
# THIS REALLY NEEDS TO BE RSPEC!!!!!!!!!!!! #
#############################################
