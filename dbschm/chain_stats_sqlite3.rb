require 'sqlite3'

if $dbschema_args.nil? || $dbschema_args.length < 1
  puts "args missing: mode"
  return
end

mode = $dbschema_args[0]

db = SQLite3::Database.new DATA_DIR + "chain_stats.db"
db.results_as_hash = true

puts "execute schema mode #{mode}"

sql = []

case mode
when :new

  begin
    db.execute("drop table block_stats;")
    db.execute("drop table rewards;")
    db.execute("drop table txos;")
  rescue
  end

  sql[0] = <<-SQL
  create table block_stats (
    hash text primary key,
    height integer,
    version integer,
    time integer,
    bits integer,
    nonce integer,
    merkleroot text,
    phash text,
    minter text,
    stakeage real,
    capital real,
    ntx integer,
    size integer,
    ssize integer,
    weight integer
  );
SQL

  sql[1] = <<-SQL
  create table rewards (
    hash text,
    idx integer,
    receiver text,
    value real,
    primary key (hash, idx)
  );
SQL

  sql[2] = <<-SQL
  create table txos (
    txid text,
    n integer,
    hash text,
    height integer,
    idx integer,
    type text,
    address text,
    value real,
    sp_height integer,
    sp_idx integer,
    sp_n integer,
    primary key (txid, n)
  );
SQL
  
when :clean
  sql[0] = "delete from block_stats;"
  sql[1] = "delete from rewards;" 
  sql[2] = "delete from txos;" 

end

sql.each_with_index do |s,i|  
  res = db.execute(sql[i]);
  
  puts "EXECUTED #{i}: #{res}";
end

$dbschema_ret = db
