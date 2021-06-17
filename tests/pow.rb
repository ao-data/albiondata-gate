require 'net/http'
require 'json'
require 'digest/sha2'
require 'securerandom'

uri = URI.parse(ARGV[0])

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

puts "pow solved after #{Time.now - start} seconds"

# Proove to the server that we solved it
response = Net::HTTP.post_form(uri + '/pow',
                    'key' => pow['key'],
                    'solution' => solution)

puts "Server says: #{response.code} #{response.body}"

# Deliver our nats ingestion
# Send a POST to the http server cotaining the topic and
# the key of the solved pow in the url
# e.g: "/marketorders.ingest/7e5ffa"
msg = {"MarketOrder": ["..."]}
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new('/marketorders.ingest/' + pow['key'])
request.body = msg.to_json
response = http.request(request)
puts "Server says: #{response.code} #{response.body}"
