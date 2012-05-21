# Copyright (c) 2009-2011 VMware, Inc.
require File.join(File.dirname(__FILE__), '..', 'spec_helper')

require 'socket'
require 'vcap/common'
require 'vcap/spec/forked_component.rb'

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

class DeaComponent < VCAP::Spec::ForkedComponent::Base
  def initialize(cmd, pid_filename, config, output_basedir)
    super(cmd, 'dea', output_basedir, pid_filename)
    @config = config
  end
end

class FileServerComponent < VCAP::Spec::ForkedComponent::Base
  def initialize(path, port, basedir)
    pidfile = '/tmp/file_server.pid'
    super("rackup #{path} -p #{port} -P #{pidfile}", 'file_server', basedir, pidfile)
  end

  def start
    Dir.chdir(@output_basedir) do
      super
    end
  end
end
