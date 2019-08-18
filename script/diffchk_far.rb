lb=lastblock.height
sb=lb - 60480
sb.step(lb,1440).each{|h| puts "#{h} => #{block(h).difficulty}"}
