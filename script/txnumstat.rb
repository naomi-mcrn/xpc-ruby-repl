puts "FIX THIS SCRIPT!!"
stt = []
(0..580).each do |d|
  bb = d * 1440 + 1
  eb = (d + 1) * 1440
  tn =  cs._db.execute("select sum(ntx-2) from block_stats where height between ? and ?",bb,eb)
  stt.push([d,tn])
end
nil
