require "net/http"

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

  COINBASE_MATURE = 101

  INSIGHT_URL_TEST = "https://cvmu.jp/insight/xpc/"
  INSIGHT_URL = "https://insight.xpchain.io/"

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
    def initialize
      super
      self.cs
      puts "blocks: #{lbh}(RPC), #{$_cs.maxblock}(ChainStats)"
      self
    end
    
    def rpc(name,*arg)
      method_missing(name,*arg)
    end

    def api(*args)
      _api(:main,*args)
    end
    
    def api_test(*args)
      _api(:test,*args)
    end

    def _api(mode,*args)      
      begin
        prms = []
        hprm = []
        args.each do |a|
          if a.is_a?(Hash)
            a.each do |k,v|
              hprm.push("#{k}=#{v}")
            end
          else
            prms.push(a.to_s)
          end
        end
        url_string = "#{mode == :main ? ::XPC::INSIGHT_URL : ::XPC::INSIGHT_URL_TEST}api/#{prms.join('/')}?#{hprm.join('&')}"
        res = Net::HTTP.get_response(URI.parse(url_string))
        JSON.parse(res.body)
      rescue => e
        puts e.to_s
        nil
      end
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

    def bsc(autosync=true)
      $_bs = scr(:block_stats)
      #$_bs.load
      if autosync
        $_bs.addprep
        #$_bs.save
      end
      $_bs
    end

    def csc(autosync=false)
      $_cs = scr(:chain_stats)
      if autosync
        $_cs.addprep
      end
      $_cs
    end

    def cs
      if $_cs.nil?
        puts "init ChainState (once)"
        csc(false)
      end
      $_cs
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
      attr = decoderawtransaction(rawtx,true) #must be TRUE!!
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
      #begin
        $script_ret = nil
        $script_args = args
        1.times do
          fn = ::ROOT_DIR + "/script/#{name.to_s}.rb"
          self.send(:eval,File.readlines(fn).join("\n"))
        end
        $script_ret
      #rescue => e
      #  puts e.to_s
      #  nil
      #end
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
      if @attrs.include?(name.to_s)
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

    #lightweight count of tx
    def txcount
      @attrs['tx'].length
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
      else
        nil
      end
    end

    def prev
      if @attrs["previousblockhash"]
        $rpc_ins.block(@attrs["previousblockhash"])
      else
        nil
      end
    end

    #avoid error on tip
    def nextblockhash
      @attrs["nextblockhash"]
    end
    
    #avoid error on genesis
    def previousblockhash
      @attrs["previousblockhash"]
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
        self.tx[0].vout.each do |v|
          rwd.push({v["scriptPubKey"]["addresses"][0] => v["value"]}) if v["value"] > 0
        end
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

    def txo
      unless @txo_cache
        @txo_cache = []
        self.vout.each do |vo|
          @txo_cache.push(TxOut.new(@attrs['txid'],vo))
        end
      end
      @txo_cache
    end

    def txi
      unless @txi_cache
        @txi_cache = []
        self.vin.each_with_index do |vi,i|
          @txi_cache.push(TxIn.new(@attrs['txid'],i,vi))
        end
      end
      @txi_cache
    end


    def inspect
      "#<XPC::Tx txid=#{@attrs['txid']} hash=#{@attrs['hash']}>"
    end
  end

  class TxOut < CoinPrim
    def initialize(txid,vo)
      @attrs = {'txid' => txid, 'n' => vo['n'], 'value' => vo['value'], 'type' => 'nonstandard', 'address' => nil }
      if vo['scriptPubKey']
        sp = vo['scriptPubKey']
        if sp['type']
          @attrs.update('type' => sp['type'])
        end
        if sp['addresses'] && sp['addresses'].length >= 1
          @attrs.update('address' => sp['addresses'][0])
          if sp['addresses'].length > 1
            @attrs.update('type' => 'notsupported')
          end
        end
      end
      @raw_data = nil
    end

    def address
      @attrs['address'] || nil
    end

    def inspect
      "#<XPC::TxOut txid=#{@attrs['txid']} n=#{@attrs['n']}>"
    end
  end

  class TxIn < CoinPrim
    def initialize(txid,n,vi)
      @attrs = {'txid' => txid, 'n' => n, 'rtxid' => vi['txid'], 'rn' => vi['vout'], 'coinbase' => false}
      if vi['coinbase']
        @attrs.update('coinbase' => true)
      end
    end

    def is_coinbase?
      @attrs['coinbase'] == true
    end

    def rtxid
      self.is_coinbase? ? "coinbase" : @attrs['rtxid']
    end

    def rn
      self.is_coinbase? ? 0 : @attrs['rn']
    end

    def tx_ref
      return nil if self.is_coinbase?
      unless @txref_cache
        @txref_cache = $rpc_ins.tx(@attrs['rtxid'])
      end
      @txref_cache
    end

    def txo_ref
      return nil if self.is_coinbase?
      begin
        self.tx_ref.txo[@attrs['rn']]
      rescue => e
        puts e.to_s
        nil
      end
    end
    
    def inspect
      "#<XPC::TxIn txid=#{@attrs['txid']} n=#{@attrs['n']} rtxid=#{@attrs['rtxid']} rn=#{@attrs['rn']}>"
    end
  end

  class Address < CoinPrim
    def initialize(addr)
      @raw_data = addr
      @attrs = {
        "address" => addr
      }
      #below suggest is too rough...
      p = addr[0]
      type = "unknown"
      case p
        when "X"
          type = "legacy"
        when "C"
          type = "p2sh_segwit"
        when "x"
          if p.length > 43
            type = "p2wsh"
          else
            type = "p2wpkh"
          end        
      end
      @attrs.update({"type" => type})
    end

    def to_s
      @attrs["address"]
    end

    def type
      @attrs["type"]
    end

    def balance(api=false)
      if api
        $rpc_ins.api("addr",self.to_s,"balance").to_i / 10000.0
      else
        $rpc_ins.cs._db.execute("select sum(value*10000) as balance from txos where sp_height = 0 and address = ?;",self.to_s)[0]["balance"].to_i / 10000.0
      end
    end

    def utxos(api=false)
      #WARNING: different info returned between api and local DB.
      if api
        $rpc_ins.api("addr",self.to_s,"utxoExt").to_a.map{|au| UnspentTxOut.new(au)}
      else
        $rpc_ins.cs._db.execute("select * from txos where sp_height = 0 and address = ?",self.to_s)
      end
    end

    def txs(api=false,safety_unlock=false)
      if !safety_unlock
        puts "ERROR: safety is locked. this method is TOOOOOO HEAVY!!" 
        return []
      end
      
      txs = []
      if api
        rtxs = $rpc_ins.api("txs",{"address" => "xpc1qvnrq3nyeklmmcev77yxs0997raxh7q4cry39gk"}).to_h["txs"].to_a
        rtxs.each do |rtx|
          txs.push($rpc_ins.tx(rtx["txid"]))
        end
      else
        saddr = self.to_s
        rtxs = $rpc_ins.cs._db.execute("select sp_height as h,sp_idx as t from txos where sp_height <> 0 and address = ? union select height as h,idx as t from txos where sp_height = 0 and address = ? order by h desc,t;",saddr,saddr)
        rtxs.each do |rtx|
          blk = $rpc_ins.block(rtx["h"])
          if blk
            ttx = blk.tx[rtx["t"]]
            if ttx
              txs.push(ttx)
            end
          end
        end
      end
      txs
    end

    def inspect
      "#<XPC::Address #{@attrs['address']} type=#{@attrs['type']}>"
    end
  end

  class UnspentTxOut < TxOut
    def initialize(au)
      @attrs = {'txid' => au['txid'], 'n' => au['vout'], 'value' => au['amount'], 'address' => au['address'], 'time' => ::Time.at(au['ts']), 'script' => au['scriptPubKey'], 'confirm' => au['confirmations'].to_i, 'coinbase' => false}
      if au['isCoinBase']
        @attrs.update({"coinbase" => true, "mature" => (au['confirmations'].to_i >= ::COINBASE_MATURE)})
      end
      @raw_data = au
    end

    def is_coinbase?
      @attrs['coinbase']
    end

    def is_spendable?
      @attrs['coinbase'] ? @attrs['mature'] : (@attrs['confirm'] > 0)
    end

    def address
      @attrs['address'] || nil
    end

    def txo
      $rpc_ins.tx(@attrs['txid']).txo[@attrs['n']]
    end

    def inspect
      "#<XPC::UnspentTxOut txid=#{@attrs['txid']} n=#{@attrs['n']} spendable=#{self.is_spendable?}>"
    end
  end
end
