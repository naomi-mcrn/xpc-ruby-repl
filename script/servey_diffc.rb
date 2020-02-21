$script_args ||= [20160]
f = File.open('/home/naomi/diffc.tsv','w+')
fin = $rpc_ins.lbh
bgn = fin - $script_args[0].to_i + 1

puts "difficulty servey #{bgn} to #{fin} (#{$script_args[0].to_i} blocks)"
(bgn..fin).each do |blk|
  b = $rpc_ins.block(blk)
  f.write("#{blk}\t#{b.time.strftime('%Y/%m/%d %H:%M:%S')}\t#{b.difficulty}\r\n")
end
f.flush
f.close
puts "DONE!"
