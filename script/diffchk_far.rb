lb=lastblock.height
sb=lb - 60480
puts "show 60480blk(42day) with 1440blk(1d) interval"
sb.step(lb,1440).each{|h| puts "#{h} => #{block(h).difficulty}"}
