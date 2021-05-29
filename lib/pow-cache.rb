$POWS = {}
$POWS_SOLVED = []

#Limit the amount of pows to keep
#Delete the oldest handed until threshold is reached
Thread.new do
  Thread.current.priority = -3 
  loop do
    begin
      if ($POWS.count - POW_KEEP) > 0
        $POWS.delete(*$POWS.keys.first($POWS.count - POW_KEEP))
      end

      if ($POWS_SOLVED.count - POW_KEEP) > 0
        $POWS_SOLVED.shift(($POWS_SOLVED.count - POW_KEEP))
      end
    ensure
      sleep 120
    end
  end
end
