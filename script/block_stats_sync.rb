bs = $rpc_ins.bsc

puts "syncing block_stats DB start"
loop do
  begin
    print "."
    if bs.maxblock != $rpc_ins.lbh
      bs.addprep
    end    
    sleep 30   
  rescue => e
    puts "ERROR: #{e.to_s}"
  end
end
