#!/usr/bin/env ruby
# Copyright (c) 2009-2011 VMware, Inc.
require 'optparse'
require 'socket'

port = nil
parser = OptionParser.new do |opts|
  opts.on('-p', '--port PORT', Integer, 'Port to bind to') do |p|
    port = p
  end
end
parser.parse(ARGV)

fail 'Must supply port' unless port

PID_FILE = '/tmp/dea_agent_test_tcpserver.pid'

File.open(PID_FILE, 'w+') do |f|
  f.write("%d\n" % (Process.pid()))
end

server = TCPServer.new('127.0.0.1', port)
while true do
  client = server.accept()
  client.close()
end
