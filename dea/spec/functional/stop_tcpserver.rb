#!/usr/bin/env ruby
# Copyright (c) 2009-2011 VMware, Inc.
puts "STOP SCRIPT!"

def process_running?(pid)
  return false unless pid && (pid > 0)
  output = %x[ps -o rss= -p #{pid}]
  return true if ($? == 0 && !output.empty?)
  # fail otherwise..
  return false
end

PID_FILE = '/tmp/dea_agent_test_tcpserver.pid'

exit 1 unless File.exists? PID_FILE

pid = File.read(PID_FILE).to_i
FileUtils.rm_f(PID_FILE)

exit 0 unless process_running?(pid)
Process.kill('TERM', pid)
