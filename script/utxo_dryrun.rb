(360000..370000).each do |bh|
  b = $rpc_ins.block(bh)
  b.tx.each_with_index do |tx,i|
    pfx = "<<" + ("% 8d" % bh) + "-" + ("%03d" % i) + ">> "
    puts pfx + " TXINS"
    tx.txi.each_with_index do |ti,vi|
      puts pfx + "   [#{vi}] #{ti.rtxid}-#{ti.rn}"
    end
    puts pfx + " TXOUTS"
    tx.txo.each_with_index do |to,vo|
      next if to.address.nil?
      puts pfx + "   [#{vo}] #{to.txid}-#{to.n} #{to.value}XPC to #{to.address[0,10]}..."
    end
  end
end
