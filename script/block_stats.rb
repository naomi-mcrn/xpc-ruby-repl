require 'sqlite3'

$script_args ||= []

unless defined?(BlockStats)
  class BlockStats
  
    def initialize
      self._db
      self
    end

    def maxblock
      _db.execute("select max(height) As result from block_stats;")[0]["result"]
    end

    def _db
      if @db.nil? || @db.closed?
        @db = SQLite3::Database.new DATA_DIR + "block_stats.db"
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
          when :reorgfix
            oldlast = blklast - 1
          else
            raise "not supported #{mode}"
        end
      end
   
      rng_bgn = (oldlast + 1)
      rng_end = blklast 
      fbh = rng_bgn
      bw = rng_end - fbh + 1
     
      progper = 0
      puts "preparing BlockStats...(mode = #{mode}, from #{rng_bgn} to #{rng_end})" unless @supmsg
      _db.transaction do
        (rng_bgn..rng_end).each do |bh|
          bd = bh - fbh + 1
          cper = (bd * 100.0 / bw).to_i
          if !@supmsg && cper != progper
            puts "%03d %%" % cper
            progper = cper
          end

          if mode == :reorgfix
            oldhash = _db.execute("select hash from block_stats where height = ?",bh)[0]["hash"]
            _db.execute("delete from block_stats where height = ?",bh)
            _db.execute("delete from rewards where hash = ?",oldhash)
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

        end
      end
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

    def inspect
      "#<XPC::RPC::BlockStats blockrange=#0..#{self.maxblock}>"
    end
  end
end

bs = BlockStats.new()
$script_ret = bs

