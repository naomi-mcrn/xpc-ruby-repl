lb=lastblock.height
sb=lb - 1440
puts "show 1440blk(1day) with 30blk interval"
sb.step(lb,30).each{|h| puts "#{h} => #{block(h).difficulty}"}
