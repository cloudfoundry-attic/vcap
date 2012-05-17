# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../spec_helper'

require 'fileutils'
require 'tmpdir'
require 'nats/client'
require 'yajl/json_gem'
require 'vcap/common'
require 'vcap/logging'
require 'vcap/spec/forked_component.rb'
require 'openssl'
require 'net/http'
require 'uri'
require "http/parser"
require "router/const"
require "router/router"

require 'pp'

class NatsServer < VCAP::Spec::ForkedComponent::Base
  def initialize(port, dir)
    @port = port
    pidfile = File.join(dir, 'nats-server.pid')
    super("ruby -S bundle exec nats-server -p #{port} -P #{pidfile}", 'nats', dir, pidfile)
  end

  def uri
    "nats://localhost:#{@port}"
  end

  def is_running?
    NATS.server_running? uri
  end
end

class RouterServer < VCAP::Spec::ForkedComponent::Base

  PORT        = 80                 # nginx listening port
  STATUS_PORT = 8081               # must be consistent with nginx config in dev_setup
  STATUS_USER = "admin"            # must be consistent with nginx config in dev_setup
  STATUS_PASSWD = "password"       # must be consistent with nginx config in dev_setup
  UNIX_SOCK   = '/tmp/router.sock' # unix socket between nginx and uls

  def initialize(nats_uri, dir)
    pidfile = File.join(dir, 'router.pid')
    logfile = File.join(dir, 'router.log')
    config_file = File.join(dir, 'router.yml')

    mbus = "mbus: #{nats_uri}"
    log_info = "logging:\n  level: debug\n  file: #{logfile}"

    config = %Q{sock: #{UNIX_SOCK}\n#{mbus}\n#{log_info}\npid: #{pidfile}\nlocal_route: 127.0.0.1\nstatus:\n  port: #{STATUS_PORT}\n  user: #{STATUS_USER}\n  password: #{STATUS_PASSWD}}

    # Write the config
    File.open(config_file, 'w') { |f| f.puts "#{config}" }

    server = File.expand_path(File.join(__FILE__, '../../../bin/router'))
    nats_timeout = File.expand_path(File.join(File.dirname(__FILE__), 'nats_timeout'))
    super("ruby -r#{nats_timeout} #{server} -c #{config_file}", 'router', dir, pidfile)
  end

  def self.unix_socket
    UNIX_SOCK
  end

  def is_running?
    require 'socket'
    s = UNIXSocket.new(UNIX_SOCK)
    s.close
    return true
  rescue
    return false
  end
end

