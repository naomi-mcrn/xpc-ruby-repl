lb=lastblock.height
sb=lb - 20160
puts "show 20160blk(14day) with 360blk(6h) interval"
sb.step(lb,360).each{|h| puts "#{h} => #{block(h).difficulty}"}
