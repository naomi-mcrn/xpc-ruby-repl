$script_args ||= []
if $script_args.length < 2
  raise ArgumentError.new("wrong number of arguments (given #{$script_args.length}, expected 2)")
end
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
    
    def clear
      @rnkdata = nil
    end 
    
    def prep(blkrange=nil)
      if blkrange
        self.init(blkrange)
      end
      @rnkdata = []
      fbh = @block_range[0]
      bw = @block_range.last - fbh + 1
      progper = 0
      puts "preparing MintStats..."
      @block_range.each do |bh|
        bd = bh - fbh + 1
        cper = (bd * 100.0 / bw).to_i
        if cper != progper
          puts "%03d %%" % cper
          progper = cper
        end
        
        blk = $rpc_ins.block(bh)
        @rnkdata.push({:minter => blk.minter, :stakeage => blk.stakeage, :rewards => blk.rewards, :rewardsum => blk.rewardsum, :capital => blk.capital})
      end
      (@block_range[0]..@block_range.last)
    end
    
    def rank(type,num=10)
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
m = MintStats.new($script_args[0])
m.clear()
m.prep()
m.rank($script_args[1].to_sym, $script_args[2])
$script_ret = m

