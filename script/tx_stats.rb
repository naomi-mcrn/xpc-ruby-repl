nm = $script_args[0] || 100
fm = {}
cbs = 0
cst = 0
fst = 0
rgr = 0
h_to = lbh
h_fr = h_to-nm
(h_fr..h_to).each do |h|
  b = $rpc_ins.block(h)
  cbs += 1
  cst += 1
  if b.tx.length > 2
    (2..(b.tx.length - 1)).each do |t|
      tx = b.tx[t]
      ff = false
      if tx.vin.length == 1 && tx.vout.length == 1
        pa = tx.prevaddrs(0)
        na = tx.addrs(0)
        if pa != nil && na != nil 
          if pa.length == 1 && na.length == 1 && pa[0] = na[0]
            fst += 1
            if fm[na[0]].nil?
              fm.update(na[0] => 1)
            else
              fm[na[0]] += 1
            end
            ff = true
          end
        end
      end
      rgr += 1 unless ff
    end
  end
end
puts "#{h_fr}..#{h_to} coinbase=#{cbs}, coinstake=#{cst}, failstake=#{fst}, regular=#{rgr}"
$script_ret = fm
nil
