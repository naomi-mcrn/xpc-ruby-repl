lb=lastblock.height
sb=lb - 20160
sb.step(lb,360).each{|h| puts "#{h} => #{block(h).difficulty}"}
