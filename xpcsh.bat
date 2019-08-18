@echo off
pry -r ./XPC.rb -e '$rpc_ins = XPC::RPCRepl.new;pry $rpc_ins;exit'