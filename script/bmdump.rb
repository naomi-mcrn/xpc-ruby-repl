
fname = (`echo $HOME`.chomp) + "/bs.csv"
bnum = 1440 * 30 * 3 #90 days
eblk = $rpc_ins.lbh
bblk = eblk - bnum + 1
puts "dump block minter from #{bblk} to #{eblk}(#{bnum})"
res = $_cs._db.execute("select height,minter from block_stats where minter is not null and height between #{bblk} and #{eblk}")

File.open(fname,"w+") do |f|
    res.each do |r|
      f.write("#{r['height']},#{r['minter']}\n")
    end
end

puts "done! (saved into #{fname})"
nil
