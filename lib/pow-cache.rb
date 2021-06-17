$POWS = {}
$POW_MUTEX = Mutex.new

#Limit the amount of pows to keep
#Delete the oldest handed until threshold is reached
Thread.new do
  Thread.current.priority = -3
  loop do
    begin
      overshoot = $POWS.count - POW_KEEP
      if (overshoot) > 0
        $POW_MUTEX.synchronize do
          $POWS.keys.first(overshoot).each { |k| $POWS.delete(k) }
        end
      end
      GC.start
    ensure
      sleep 120
    end
  end
end
