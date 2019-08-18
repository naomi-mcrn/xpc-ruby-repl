$script_args ||= []
#if $script_args.length < 2
#  raise ArgumentError.new("wrong number of arguments (given #{$script_args.length}, expected 2)")
#end
unless defined?(MintStats)
  class MintStats
    def initialize(blkrange)
      self.init(blkrange)
      self.clear()
    end
    
    def init(blkrange)
      @block_range = nil
      case true
        when blkrange.is_a?(Integer)
          lh = $rpc_ins.lastblock.height
          @block_range = ((lh - blkrange + 1)..lh).to_a
        when blkrange.is_a?(Range)
          @block_range = blkrange.to_a
        when blkrange.is_a?(Array)   
          @block_range = blkrange.dup
        else
          raise TypeError.new("#{blkrange.class} can't convert to array.")
      end
      (@block_range[0]..@block_range.last)
    end

    def save(filename=nil)
      begin
        if (@rnkdata.nil? || @rnkdata.length < 1)
          raise "mintstats not prepared"
        end
        if @block_range[0] + @rnkdata.length - 1 != @block_range.last
          raise "block range is not continuous"
        end 
        filename = filename.to_s.split("/").last.to_s.split("\\").last.to_s.split(".").last.to_s
        if filename != ""
          filename = "_#{filename}"
        end
        fn = DATA_DIR + "mint_stats#{filename}.dat"
        File.open(fn,"wb") do |f|
          f.write([@block_range[0]].pack("Q!"))
          f.write(Marshal.dump(@rnkdata))
        end
        true
      rescue => e
        puts e.to_s
        false
      end
    end

    def load(filename=nil)
      begin
        filename = filename.to_s.split("/").last.to_s.split("\\").last.to_s.split(".").last.to_s
        if filename != ""
          filename = "_#{filename}"
        end
        fn = DATA_DIR + "mint_stats#{filename}.dat"
        _blkrng_bgn = -1
        _rnkdat = nil
        File.open(fn,"rb") do |f|
          _blkrng_bgn = f.read(8).unpack("Q!")[0]
          _rnkdat = Marshal.load(f.read(f.size - 8))
        end
        @block_range = (_blkrng_bgn..(_blkrng_bgn + _rnkdat.length - 1)).to_a
        @rnkdata = _rnkdat
        true
      rescue => e
        puts e.to_s
        false
      end
    end
    
    def clear
      @rnkdata = nil
    end 

    def supmsg(sup)
      @supmsg = sup
    end
    
    def addprep(blklast=nil)
      raise "not prepared yet!" if @rnkdata.nil?
      if blklast.nil?
        blklast = $rpc_ins.getblockcount
      end
      prep(blklast,:update)
    end

    def prep(blkrange=nil,mode=:new)
      oldlast = -1
      if blkrange
        case mode
          when :new
            self.init(blkrange)
          when :update
            oldlast = @block_range.last
            self.init(@block_range[0]..blkrange)
          else
            raise
        end
      end

      rng = nil
      fbh = -1
      bw = -1
      if mode == :new
        rng = @block_range
        @rnkdata = []
        fbh = @block_range[0]
        bw = @block_range.last - fbh + 1
      else
        rng = ((oldlast + 1)..@block_range.last).to_a 
        @rnkdata ||= []
        fbh = rng[0]
        bw = rng.last - fbh + 1
      end
      progper = 0
      puts "preparing MintStats...(mode = #{mode.to_s}, from #{rng[0]} to #{rng.last})" unless @supmsg
      rng.each do |bh|
        bd = bh - fbh + 1
        cper = (bd * 100.0 / bw).to_i
        if !@supmsg && cper != progper
          puts "%03d %%" % cper
          progper = cper
        end
        
        blk = $rpc_ins.block(bh)
        @rnkdata.push({:minter => blk.minter, :stakeage => blk.stakeage, :rewards => blk.rewards, :rewardsum => blk.rewardsum, :capital => blk.capital})
      end
      (@block_range[0]..@block_range.last)
    end
    
    def rank(type=:count,num=10)
      num ||= 10
      if @rnkdata.nil?
        self.prep
      end
      rnkdic = {}
      @rnkdata.each do |rd|
        ad = nil
        nu = 0
        case type
          when :count
            ad = rd[:minter]
              nu = 1
          when :reward
            ad = rd[:minter]
            nu = rd[:rewardsum]
          when :capital
            ad = rd[:minter]
            nu = rd[:capital] 
          when :rewardto,:increase,:give,:take
            raise "not yet implemented"
        end
        
        if ad && nu > 0
          if rnkdic[ad].nil?
            rnkdic.update({ad => nu})
          else
            rnkdic[ad] += nu
          end
        end
      end
      rnkbrd = rnkdic.to_a.map{|e| e.flatten}.sort{|a,b| b[1] <=> a[1]}
      num.times do |i|
        break if rnkbrd[i].nil?
        puts "#{i+1},#{rnkbrd[i][0]}, #{rnkbrd[i][1]}"
      end
      nil
    end

    def inspect
      "#<XPC::RPC::MintStats blockrange=#{@block_range[0]}..#{@block_range.last}>"
    end
  end
end
rng = $script_args[0] || [0]
type = ($script_args[1] || "count").to_sym
rnknm = $script_args[2]

m = MintStats.new(rng)
m.clear()
m.prep()
m.rank(type, rnknm)
$script_ret = m

