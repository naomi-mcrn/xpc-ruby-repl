begin
  load "config.rb"
rescue LoadError 
  ROOT_DIR = "/home/naomi/labs/"
  DATA_DIR = ROOT_DIR + "/data/"
end
load ROOT_DIR + "util.rb"
load ROOT_DIR + 'lib/rpc/xpc.rb'
load ROOT_DIR + 'secret/cred.rb' #private file!
$_blk = nil
$_tx = nil
module XPC
  GENESIS_BLOCK_HASH = "000000009f4a28557aad6be5910c39d40e8a44e596d5ad485a9e4a7d4d72937c"
  GENESIS_COINBASE_TXID = "daa610662c202dd51c892e6ff17ac1812a3ddcb998ec4923a3a315c409019739"

  class ShellRPCRepl
    def method_missing(name,*arg)
      res = `xpchain-cli #{name} #{arg.join(' ')} 2>&1`.chop
      begin
        JSON.parse(res)
      rescue => e
        puts res
        nil
      end
    end
  end

  class HTTPRPCRepl
    @cli = nil
    def initialize
      @cli = XPC::RPC::Client.new("user" => ::XPC::Secret::HTTP_RPC_USER, "pass" => ::XPC::Secret::HTTP_RPC_PASS, "host" => ::XPC::Secret::HTTP_RPC_HOST, "port" => ::XPC::Secret::HTTP_RPC_PORT)
    end

    def method_missing(name,*arg)
      json = @cli.execrpc(name,*arg)
      if json["errors"].nil?
        json["result"]
      else
        puts json["errors"].to_s
        nil
      end
    end
  end

  class RPCRepl < HTTPRPCRepl
    def rpc(name,*arg)
      method_missing(name,*arg)
    end

    def lastblock
      blkh = getblockhash(getblockcount)
      h = getblock(blkh,true)
      r = getblock(blkh,false)
      $_blk = Block.new(h,r)
      $_blk
    end

    def lbh
      getblockcount
    end

    def lb
      lastblock
    end

    def bs(autosync=true)
      $_bs = scr(:block_stats)
      $_bs.load
      if autosync
        $_bs.addprep
        $_bs.save
      end
      $_bs
    end

    def block(arg,hdonly=false)
      h = nil
      r = nil
      if arg.is_a?(String)
        blkh = arg
      else
        blkh = getblockhash(arg)
      end
      if hdonly
        h = getblockheader(blkh,true)
        r = getblockheader(blkh,false)
      else
        h = getblock(blkh,true)
        r = getblock(blkh,false)
      end
      if (h.nil? || r.nil?)
        nil
      else
        $_blk = Block.new(h,r)
        $_blk
      end
    end

    def header(arg)
      block(arg,true)
    end

    def tx(txid)
      rawtx = ""
      attr = {}
      dattr = {}
        begin
      if txid == ::XPC::GENESIS_COINBASE_TXID
        dattr = {"blockhash" => ::XPC::GENESIS_BLOCK_HASH}
        rawtx = getblock(::XPC::GENESIS_BLOCK_HASH,false)[162..-1]
      else
        dattr = getrawtransaction(txid,true)
        rawtx = dattr.delete("hex")
      end
      attr = decoderawtransaction(rawtx)
      dattr.update(attr)
      $_tx = Tx.new(dattr,rawtx)
        $_tx
        rescue => e
        puts e.to_s
          puts dattr
          puts attr
      end
    end

    def scr(name,*args)
      begin
        $script_ret = nil
        $script_args = args
        1.times do
          fn = ::ROOT_DIR + "/script/#{name.to_s}.rb"
          self.send(:eval,File.readlines(fn).join("\n"))
        end
        $script_ret
      rescue => e
        puts e.to_s
        nil
      end
    end
    
    def listscr(query=nil)
      lst = Dir.entries(::ROOT_DIR + "/script").select{|n| n =~ /.+\.rb/ && (query.nil? || n =~ /#{query}/)}.map{|n| n.gsub(/\.rb/,"").to_sym}
      puts lst
      lst
    end

    def dbschm(name,*args)
      begin
        $dbschema_ret = nil
        $dbschema_args = args
        1.times do
          fn = ::ROOT_DIR + "/dbschm/#{name.to_s}.rb"
          self.send(:eval,File.readlines(fn).join("\n"))
        end
        $dbschema_ret
      rescue => e
        puts e.to_s
        nil
      end
    end

    def listdbschm(query=nil)
      lst = Dir.entries(::ROOT_DIR + "/dbschm").select{|n| n =~ /.+\.rb/ && (query.nil? || n =~ /#{query}/)}.map{|n| n.gsub(/\.rb/,"").to_sym}
      puts lst
      lst
    end

    def bench(&block)
      raise "no block given" unless block_given?
      t1 = Time.now
      yield 
      t2 = Time.now
      puts "Bench: elapsed #{t2-t1}" 
      nil
    end
  end

  class CoinPrim < BasicObject
    
    def initialize(a,r)
      @attrs = a
      @raw_data = r
      a
    end

    def respond_to?(*arg)
      false
    end

    def method_missing(name,*arg)
      if @attrs[name.to_s]
        @attrs[name.to_s]
      else
        super(name,*arg)
      end
    end

    def attr_keys
      @attrs.keys.map{|k| k.to_sym}
    end

    def raw_attrs
      @attrs
    end

    def raw_data
      @raw_data
    end

    def inspect
      "#<XPC::CoinPrim>"
    end

    def to_s
      self.inspect
    end

  end

  class Block < CoinPrim
    def is_full?
      !(@attrs["tx"].nil? || @attrs["size"].to_i < 1)
    end

    def to_full
      if self.is_full?
        self
      else
        $rpc_ins.block(self.txid)
      end
    end

    def version
      {dec: @attrs["version"], hex: @attrs["versionHex"]}
    end

    def time
      ::Time.at(@attrs["time"])
    end
    
    def mediantime
      ::Time.at(@attrs["mediantime"])
    end

    def tx
      if @tx_cache.nil?
        @tx_cache = @attrs["tx"].map{|txid| $rpc_ins.tx(txid)}
      end
      @tx_cache
    end

    def coinbase
      cb = tx[0].vin[0]["coinbase"]
      {hex: cb, str: [cb].pack("H*")}
    end

    def next
      if @attrs["nextblockhash"]
        $rpc_ins.block(@attrs["nextblockhash"])
      end
    end

    def prev
      $rpc_ins.block(@attrs["previousblockhash"])
    end

    def stakeage
      if tx.length < 2
        nil
      else
        begin
          (self.time - $rpc_ins.tx(self.tx[1].vin[0]["txid"]).block.time) / 86400.0
        rescue
          nil
        end
      end
    end

    def minter
      begin
        mtr1 = self.tx[1].vout[0]["scriptPubKey"]["addresses"][0]
        vin = self.tx[1].vin[0]
        mtr2 = $rpc_ins.tx(vin["txid"]).vout[vin["vout"]]["scriptPubKey"]["addresses"][0]
        if mtr1 == mtr2
          mtr1
        else
          nil
        end
      rescue => e
        nil
      end
    end

    def rewards
      begin        
        rwd = []
        self.tx[0].vout.each{|v| rwd.push({v["scriptPubKey"]["addresses"][0] => v["value"]}) if v["value"] > 0}
        rwd
      rescue => e
        puts "ERROR: " + e.to_s
        nil
      end
    end
    
    def rewardsum
      rttl = 0
      rwds = self.rewards
      return nil if rwds.nil?
      rwds.each do |rwd|
        rwd.each do |k,v|
          rttl += v
        end
      end
      rttl
    end

    def capital
      begin
        # mtr1 = self.tx[1].vout[0]["scriptPubKey"]["addresses"][0]
        vin = self.tx[1].vin[0]
        cap = $rpc_ins.tx(vin["txid"]).vout[vin["vout"]]["value"]
        cap
      rescue => e
        nil
      end
    end

    def stats
      blk = self
      {
        hash: @attrs["hash"],
        height: @attrs["height"],
        version: @attrs["version"],
        time: @attrs["time"],
        bits: @attrs["bits"].to_i(16),
        nonce: @attrs["nonce"],
        merkleroot: @attrs["merkleroot"],
        phash: @attrs["previousblockhash"],

        minter: blk.minter, 
        stakeage: blk.stakeage, 
        rewards: blk.rewards,
        rewardsum: blk.rewardsum, 
        capital: blk.capital,

        ntx: @attrs["nTx"],
        size: @attrs["size"],
        ssize: @attrs["strippedsize"],
        weight: @attrs["weight"],
      }
    end

    def inspect
      "#<XPC::Block full=#{is_full?} height=#{@attrs['height']} hash=#{@attrs['hash']}>"
    end    
  end

  class Tx < CoinPrim
    def block
      if @attrs["blockhash"]
        $rpc_ins.block(@attrs["blockhash"])
      end
    end

    def blocktime
       ::Time.at(@attrs["blocktime"])
    end

    def prevtxo(i)
      $rpc_ins.tx(self.vin[i]["txid"]).vout[self.vin[i]["vout"]]
    end

    def prevaddrs(i)
      begin
        self.prevtxo(i)["scriptPubKey"]["addresses"]
      rescue 
        nil
      end
    end

    def addrs(i)
      begin
        self.vout[i]["scriptPubKey"]["addresses"]
      rescue 
        nil
      end
    end

    def inspect
      "#<XPC::Tx txid=#{@attrs['txid']} hash=#{@attrs['hash']}"
    end
  end
end
