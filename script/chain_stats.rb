require 'sqlite3'

$script_args ||= []

unless defined?(ChainStats)
  class ChainStats
  
    def initialize
      self._db
      self
    end

    def maxblock
      _db.execute("select max(height) As result from block_stats;")[0]["result"] || -1
    end

    def utxocount
      _db.execute("select count(*) As result from txos where sp_height = 0;")[0]["result"] || -1
    end

    def _db
      if @db.nil? || @db.closed?
        @db = SQLite3::Database.new DATA_DIR + "chain_stats.db"
        @db.results_as_hash = true
        @db.busy_handler do |d,r|
          puts "SQLite3: BUSY retry=#{r}"
          true #always retry
        end
      end
      @db
    end

    def _bwc
      puts "warning: for backward compatible only (do nothing)"
      true
    end

    def save(*args)
      self._bwc
    end
    
    def load(*args)
      self._bwc
    end
      
    def init(*args)
      self._bwc
    end
    
    def clear
      puts "warning: clear from #{self.class} is disabled! (DANGEROUS!)"
      nil
    end 

    def supmsg(sup)
      @supmsg = sup
    end
    
    def addprep(blklast=nil,debug=false)
      if blklast.nil?
        blklast = $rpc_ins.getblockcount
      end
      puts "current last block (coind) = #{$rpc_ins.getblockcount}, blklast = #{blklast}, maxblock = #{self.maxblock}" if debug
      if (self.maxblock < blklast)        
        prep(blklast,:update)
      end
    end

    def prep(blklast=nil,mode=:update)
      raise "last block must be set" if blklast.nil?
      raise "last block must be numeric" unless blklast.is_a?(Numeric)
      oldlast = -1
      if blklast
        case mode
          when :update
            oldlast = self.maxblock
          else
            raise "not supported #{mode}"
        end
      end
   
      rng_bgn = (oldlast + 1)
      rng_end = blklast 

      #reorg check
      
      loop do
        break if oldlast < 0
        blk = $rpc_ins.block(rng_bgn)
        tiphash = _db.execute("select hash from block_stats where height = ?",oldlast)[0]["hash"]
        if blk.previousblockhash != tiphash          
          puts "REORG at #{rng_bgn - 1}, old = #{tiphash}, new = #{blk.previousblockhash}" unless @supmsg
          _db.execute("delete from block_stats where hash = ?",tiphash)
          _db.execute("delete from rewards where hash = ?",tiphash)
          _db.execute("delete from txos where hash = ?",tiphash)
          _db.execute("update txos set sp_height = 0,sp_idx = 0,sp_n = 0 where sp_height = ?",oldlast)

          rng_bgn -= 1
          oldlast -= 1                    
          next
        end
        break
      end

      fbh = rng_bgn
      bw = rng_end - fbh + 1
     
      progper = 0
      puts "preparing ChainStats...(mode = #{mode}, from #{rng_bgn} to #{rng_end})" unless @supmsg
     # _db.transaction do
      _db.execute("BEGIN;")
      begin
        (rng_bgn..rng_end).each do |bh|
          #bd = bh - fbh + 1
          #cper = (bd * 100.0 / bw).to_i
          #if !@supmsg && cper != progper
          #  puts "%03d %%" % cper
          #  progper = cper
          #end
          
          if (bh % 500 == 0)
            _db.execute("COMMIT;")
            _db.execute("BEGIN;")
            unless @supmsg
              bd = bh - fbh + 1
              cper = (bd * 100.0 / bw).to_i
              
              puts "#{'% 8d' % bh}/#{'% 8d' % rng_end} #{'% 3d' % cper} %"
            end
          end
          
        
          blk = $rpc_ins.block(bh)
          d = blk.stats
          
          _db.execute("insert into block_stats values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
                     d[:hash],
                     d[:height],
                     d[:version],
                     d[:time],
                     d[:bits],
                     d[:nonce],
                     d[:merkleroot],
                     d[:phash],
                     d[:minter],
                     d[:stakeage],
                     d[:capital],
                     d[:ntx],
                     d[:size],
                     d[:ssize],
                     d[:weight])
          
          
          d[:rewards].each_with_index do |rwd,i|
            _db.execute("insert into rewards values (?,?,?,?);",
                       d[:hash],
                       i,
                       rwd.keys[0],
                       rwd.values[0])
            
          end


          blk.tx.each_with_index do |ttx,vtx|
            ttx.txi.each_with_index do |ti,vi|
              unless ti.is_coinbase?                               
                _db.execute("update txos set sp_height=?,sp_idx=?,sp_n=? where txid=? and n=?;",blk.height,vtx,vi,ti.rtxid,ti.rn)
              end
            end
            ttx.txo.each_with_index do |to,vo|
              next if to.address.nil?
              _db.execute("insert into txos values (?,?,?,?,?,?,?,?,?,?,?);",
                          to.txid,to.n,blk.hash,blk.height,vtx,to.type,to.address,to.value,
                          0,0,0)
            end
          end


        end
        _db.execute("COMMIT;")
      rescue => e
        _db.execute("ROLLBACK;")
      end

      
      #end
      (0..self.maxblock)
    end

    def raw_data
      puts "warning: raw_data is disabled. use data(height) for individual data"
      nil
    end

    def data(bh)
      res = _db.execute("select * from block_stats where height = ?",bh)[0]
      if res
        r2 = _db.execute("select idx,receiver,value from rewards where hash = ? order by idx",res["hash"])
        if r2 && r2.length > 0
          res.update("rewards" => r2)
          rs = 0.0
          r2.each do |rwd|
            rs += rwd["value"]
          end
          res.update("rewardsum" => rs)
        end
      end
      res
    end

    def rrank(rcnt=1440,type=:count,num=10,fd=nil)
      h = $rpc_ins.lbh
      puts "recent rank from #{h-rcnt+1} to #{h} (#{rcnt} block(s))"
      self.rank(type,num,h-rcnt,h,fd)
    end
    
    def rank(type=:count,num=10,fb=-1,lb=-1,fd=nil)
      num ||= 10
      sql = nil
      psql = []
      pprm = []
      fb = fb.to_i
      lb = lb.to_i
     
      if fb > -1
        psql.push("height >= ?")
        pprm.push(fb)
      end
      if lb > -1
        psql.push("height <= ?")
        pprm.push(lb)
      end

      case type
        when :count
          sql = "select minter as r1,count(*) as r2 from block_stats where minter is not null"
   
          if psql.length > 0
            sql += " and " + psql.join(" and ")
          end
          sql +=" group by r1 order by r2 desc;"
        when :reward
          sql = "select minter as r1,sum(value) as r2 from block_stats inner join rewards on block_stats.hash = rewards.hash where minter is not null"

          if psql.length > 0
            sql += " and " + psql.join(" and ")
          end
          sql +=" group by r1 order by r2 desc;"           
        when :capital
          sql = "select minter as r1,capital as r2 from block_stats where minter is not null"

          if psql.length > 0
            sql += " and " + psql.join(" and ")
          end
          sql +=" group by r1 order by r2 desc;" 
        when :increase
          sql = "select minter as r1,avg(stakeage) as r2 from block_stats where minter is not null"

          if psql.length > 0
            sql += " and " + psql.join(" and ")
          end
          sql +=" group by r1 order by r2 desc;"
        when :rewardto,:give,:take
          raise "not yet implemented"
      end
        
      if sql
        sql += " limit #{num}"
        #puts sql
        lcnt = 0
        _db.execute(sql,*pprm).each_with_index do |rcd,i|
          aa = "#{i+1},#{rcd['r1']},#{rcd['r2']}"
          if fd
            fd.write(aa+"\n")
          else
            puts aa
          end
          lcnt += 1
          break if lcnt >= num
        end
      end
     
      nil
    end

    def prep_richlist
      _db.transaction do
        mb = self.maxblock
        puts "make richlist at block #{mb}"
        _db.execute("delete from richlist;")
        _db.execute("insert into richlist select address,sum(value) as balance from txos where sp_height = 0 group by address order by balance desc;")
        adrs = _db.execute("select count(*) as adrs from richlist;")[0]["adrs"]
        puts "total addresses = #{adrs}"
        nil
      end
    end

    def richlist(num=10,offset=nil,f=nil)
      sqlp=[]
      skip = offset || 0
      i = skip
      sql = "select * from richlist order by value desc limit ?"
      sqlp.push(num)
      if offset
        sql += " offset ?"
        sqlp.push(offset)
      end
      sql += ";"
      _db.execute(sql,*sqlp).each do |r|
        i += 1
        aa = "#{i},#{r['address']},#{r['value']}"
        if f
          f.write(aa+"\r\n");
        else
          puts aa
        end
      end      
      nil
    end

    def rlquery(query)
      if query.is_a?(String)
        raise "bad query! injection!!" unless (query =~ /^[a-zA-Z0-9]/)
        r = _db.execute("select * from richlist where address like '%" + query + "';")[0]
        puts "match #{r['address']}"
        v = r['value'].to_f
      else
        v = query.to_f
      end
      _db.execute("select count(*) as rnk from richlist where value > ?",v)[0]["rnk"].to_i + 1
    end

    def addrs(query)
      query = query.to_s
      raise "bad query! injection!!" unless (query =~ /^[a-zA-Z0-9]/)
      r = _db.execute("select address from richlist where address like '%" + query + "';")
      if r.length > 0
        r.map{|rr| ::XPC::Address.new(rr["address"])}
      else
        nil
      end
    end

    def balance(query)
      raise "bad query! injection!!" unless (query =~ /^[a-zA-Z0-9]/)
      _db.execute("select sum(value) as balance from txos where address like '%" + query + "' and sp_height = 0;")[0]["balance"]
    end

    def inspect
      "#<XPC::RPC::ChainStats blockrange=#0..#{self.maxblock} utxos=#{self.utxocount}>"
    end
  end
end

cs = ChainStats.new()
$script_ret = cs

