#utxo mempool
# key = txid-vout
# value = hash(address,value)

bgn = $script_args[0] || 0
fin = $script_args[1] || 10275

utxos = {}

(bgn..fin).each do |bh|
  puts "[BLOCK " + ("% 8d" % bh) + "] " + Time.now.to_s if (bh % 1000 == 0)
  b = $rpc_ins.block(bh)
  b.tx.each_with_index do |tx,i|
    pfx = "<<" + ("% 8d" % bh) + "-" + ("%03d" % i) + ">> "
    tx.txi.each_with_index do |ti,vi|
      unless ti.is_coinbase?
        key = "#{ti.rtxid}-#{ti.rn}"
        if utxos[key].nil?
          puts " !!PHANTOM SPENT!! #{key} in block #{bh}, tx #{tx.txid}"
        else
          utxos.delete(key)
        end
        #puts pfx + "   SPENT #{key}"
      end
    end

    tx.txo.each_with_index do |to,vo|
      next if to.address.nil?
      key = "#{to.txid}-#{to.n}"
      utxos.update(key => {"address" => to.address, "value" => to.value})
      #puts pfx + " UNSPENT #{key} #{to.address} #{to.value}"
    end
  end
end

$script_ret = utxos
