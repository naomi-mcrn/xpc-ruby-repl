#!/usr/bin/bash
pry -r /home/naomi/labs/XPC.rb  -e '$rpc_ins = XPC::RPCRepl.new;pry $rpc_ins;exit'

