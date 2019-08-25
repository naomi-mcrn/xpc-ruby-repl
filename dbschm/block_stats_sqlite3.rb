require 'sqlite3'

if $dbschema_args.nil? || $dbschema_args.length < 4
  puts "args missing: mode data begin end"
  return
end

mode = $dbschema_args[0]
data = $dbschema_args[1]
d_bgn = $dbschema_args[2]
d_end = $dbschema_args[3]

db = SQLite3::Database.new DATA_DIR + "block_stats.db"
db.results_as_hash = true

puts "execute schema mode #{mode}"

sql = []

case mode
when :new

begin
  db.execute("drop table block_stats;")
  db.execute("drop table rewards");
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

when :add


when :clean
  sql[0] = <<-SQL
  delete from block_stats;
  delete from rewards; 
SQL

end

sql.each_with_index do |s,i|

res = db.execute(sql[i]);

puts "EXECUTED #{i}: #{res}";
end


db.transaction do
(d_bgn..d_end).each do |i|

puts i if (i % 100 == 0)
  d = data[i]

  db.execute("insert into block_stats values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
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
    db.execute("insert into rewards values (?,?,?,?);",
               d[:hash],
               i,
               rwd.keys[0],
               rwd.values[0])
               
  end
  
end
end
$dbschema_ret = db
