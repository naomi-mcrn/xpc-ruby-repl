cs = $rpc_ins.csc(false)

puts "syncing chain_stats DB start"
loop do
  #begin
    print "."
    if cs.maxblock != $rpc_ins.lbh
      cs.addprep
    end    
    sleep 30   
  #rescue => e
  #  puts "ERROR: #{e.to_s}"
  #end
end
