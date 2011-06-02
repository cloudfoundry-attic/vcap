# Copyright (c) 2009-2011 VMware, Inc.
require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'socket'
require 'vcap/common'

def port_open?(port)
  port_open = true
  begin
    s = TCPSocket.new('localhost', port)
    s.close()
  rescue
    port_open = false
  end
  port_open
end

def wait_for(timeout=10, &predicate)
  start = Time.now()
  cond_met = predicate.call()
  while !cond_met && ((Time.new() - start) < timeout)
    cond_met = predicate.call()
    sleep(0.2)
  end
  cond_met
end

class ForkedComponent
  attr_reader :pid

  def initialize(cmd, pid_filename, name, output_basedir='/tmp')
    @cmd = cmd
    @pid_filename = pid_filename
    @name = name
    @output_basedir = output_basedir
  end

  def start
    fork do
      fn = File.join(@output_basedir, "#{@name}.#{Process.pid}.out")
      outfile = File.new(fn, 'w+')
      $stderr.reopen(outfile)
      $stdout.reopen(outfile)
      exec(@cmd)
    end
    wait_for { File.exists? @pid_filename }
    @pid = File.read(@pid_filename).chomp.to_i()
  end

  def stop
    return unless @pid && VCAP.process_running?(@pid)
    Process.kill('TERM', @pid)
    Process.waitpid(@pid, 0)
    FileUtils.rm_f(@pid_filename)
    @pid = nil
  end

  def is_running?
    VCAP.process_running?(@pid)
  end
end

class NatsComponent < ForkedComponent
  attr_reader :port
  attr_reader :uri

  def initialize(opts)
    super(opts[:cmd], opts[:pid_file], 'nats', opts[:outdir])
    @port = opts[:port]
    @uri = opts[:uri]
  end

  def is_ready?
    VCAP.process_running?(@pid) && port_open?(@port)
  end
end

class DeaComponent < ForkedComponent
  def initialize(cmd, pid_filename, config, output_basedir)
    super(cmd, pid_filename, 'dea', output_basedir)
    @config = config
  end
end
