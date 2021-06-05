TOPICS = %w(goldprices.ingest marketorders.ingest markethistories.ingest mapdata.ingest)
#NATS_URI = "nats://public:thenewalbiondata@www.albion-online-data.com:4222"
NATS_URI = "nats://localhost:4222"

# Each ingestion takes 3 REQUEST
# get pow
# submit pow
# ingest
REQUEST_LIMIT = {
  per_day: 10_000 * 3,
  per_hour: 1_000 * 3,
  per_minute: 90 * 3,
}

# Number of handed pows to remember (prevents out of memory)
POW_KEEP = 10_000

# Higher difficulity will take the client more time to solve
# Benchmark: https://docs.google.com/spreadsheets/d/1aongAIvJs0idA9ABk_saGIyeyvZJL9glxf1vsaCO5MY/edit?usp=sharing
POW_DIFFICULITY=39

# Higher randomness will make it harder to store all possible combinations
# If it is to low the pows can be pre-solved, stored and lookedup as needed
# Formular for possible combinations: (POW_RANDOMNESS^16)*(POW_DIFFICULITY^2)
# e.g.: (8^16)*(32^2) = 288,230,376,151,711,744 (~ two hundred eighty-eight quadrillion)
#       (3^16)*(32^2) = 44,079,842,304          (~ forty-four billion)
POW_RANDOMNESS=3
