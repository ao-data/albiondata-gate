TOPICS = %w(goldprices.ingest marketorders.ingest markethistories.ingest mapdata.ingest)
NATS_URI = ENV['NATS_URI']

# Each ingestion takes 2 REQUEST
# get pow
# submit pow & ingestion
REQUEST_LIMIT = {
  per_day: 30_000 * 2,
  per_hour: 3_000 * 2,
  per_minute: 270 * 2,
}

# Number of handed pows to remember (prevents out of memory)
POW_KEEP = 10_000

# Higher difficulity will take the client more time to solve
# Benchmark: https://docs.google.com/spreadsheets/d/1aongAIvJs0idA9ABk_saGIyeyvZJL9glxf1vsaCO5MY/edit?usp=sharing
POW_DIFFICULITY =  ENV['POW_DIFFICULITY'].nil? ? 39 : ENV['POW_DIFFICULITY'].to_i

# Limits the size of a nats payload
# 32768 should be large enough for any corrctly functioning client
NATS_PAYLOAD_MAX =  ENV['NATS_PAYLOAD_MAX'].nil? ? 32768 : ENV['NATS_PAYLOAD_MAX'].to_i

# Higher randomness will make it harder to store all possible combinations
# If it is to low the pows can be pre-solved, stored and lookedup as needed
# Formular for possible combinations: (POW_RANDOMNESS^16)*(POW_DIFFICULITY^2)
# e.g.: (8^16)*(32^2) = 288,230,376,151,711,744 (~ two hundred eighty-eight quadrillion)
#       (3^16)*(32^2) = 44,079,842,304          (~ forty-four billion)
POW_RANDOMNESS=3
