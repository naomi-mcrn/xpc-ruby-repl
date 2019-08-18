lb=lastblock.height
sb=lb - 1440
sb.step(lb,30).each{|h| puts "#{h} => #{block(h).difficulty}"}
