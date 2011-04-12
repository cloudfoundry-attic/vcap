# Copyright (c) 2009-2011 VMware, Inc.
require 'fileutils'
require 'logger'
require 'optparse'
require 'socket'
require 'yaml'
require 'openssl'

require 'rubygems'
require 'bundler/setup'

require 'nats/client'
require 'http/parser'

require 'vcap/common'
require 'vcap/component'

$:.unshift(File.dirname(__FILE__))

require 'router/const'
require 'router/router'
require 'router/app_connection'
require 'router/client_connection'
require 'router/utils'

config_file = File.join(File.dirname(__FILE__), '../config/router.yml')
port, inet = nil, nil

options = OptionParser.new do |opts|
  opts.banner = 'Usage: router [OPTIONS]'
  opts.on("-p", "--port [ARG]", "Network port") do |opt|
    port = opt.to_i
  end
  opts.on("-i", "--interface [ARG]", "Network Interface") do |opt|
    inet = opt
  end
  opts.on("-c", "--config [ARG]", "Configuration File") do |opt|
    config_file = opt
  end
  opts.on("-h", "--help", "Help") do
    puts opts
    exit
  end
end
options.parse!(ARGV.dup)

begin
  config = File.open(config_file) do |f|
    YAML.load(f)
  end
rescue => e
  puts "Could not read configuration file:  #{e}"
  exit
end

# Placeholder for Component reporting
config['config_file'] = File.expand_path(config_file)

port = config['port'] unless port
inet = config['inet'] unless inet

EM.epoll

EM.run {

  trap("TERM") { stop(config['pid']) }
  trap("INT")  { stop(config['pid']) }

  Router.config(config)
  Router.log.info "Starting VCAP Router (#{Router.version})"
  Router.log.info "Listening on: #{inet}:#{port}" if inet && port

  Router.inet = inet || VCAP.local_ip(config['local_route'])
  Router.port = port

  # If the sock paramater is set, this will override the inet/port
  # for unix domain sockets
  if fn = config['sock']
    File.unlink(fn) if File.exists?(fn)
    Router.log.info "Listening on unix domain socket: '#{fn}'"
  end

  # Hack for running on BVTs on Macs which default to 256 FDs per process
  if RUBY_PLATFORM =~ /darwin/
    begin
      Process.setrlimit(Process::RLIMIT_NOFILE, 4096)
    rescue => e
      Router.log.info "Failed to modify the socket limit: #{e}"
    end
  end

  EM.set_descriptor_table_size(32768) # Requires Root privileges
  Router.log.info "Socket Limit:#{EM.set_descriptor_table_size}"

  create_pid_file(config['pid'])

  EM.error_handler { |e|
    if e.kind_of? NATS::Error
      Router.log.error("NATS problem, #{e}")
    else
      Router.log.error "Eventmachine problem, #{e}"
      Router.log.error("#{e.backtrace.join("\n")}")
    end
  }

  begin
    # TCP/IP Socket
    Router.server = EM.start_server(inet, port, ClientConnection, false) if inet && port
    Router.local_server = EM.start_server(fn, nil, ClientConnection, true) if fn
  rescue => e
    Router.log.fatal "Problem starting server, #{e}"
    exit
  end

  # Allow nginx to access..
  FileUtils.chmod(0777, fn) if fn

  NATS.start(:uri => config['mbus'])

  # Create the register/unregister listeners.
  Router.setup_listeners

  # Register ourselves with the system
  VCAP::Component.register(:type => 'Router',
                           :host => VCAP.local_ip(config['local_route']),
                           :config => config)

  # Setup some of our varzs..
  VCAP::Component.varz[:requests] = 0
  VCAP::Component.varz[:bad_requests] = 0
  VCAP::Component.varz[:urls] = 0
  VCAP::Component.varz[:droplets] = 0

  @router_id = VCAP.fast_uuid
  @hello_message = { :id => @router_id, :version => Router::VERSION }.to_json.freeze

  Router.log_connection_stats

  # This will check on the state of the registered urls, do maintenance, etc..
  Router.setup_sweepers

  # Setup a start sweeper to make sure we have a consistent view of the world.
  EM.next_tick {
    # Announce our existence
    NATS.publish('router.start', @hello_message)
    EM.add_periodic_timer(START_SWEEPER) { NATS.publish('router.start', @hello_message) }
  }
}

