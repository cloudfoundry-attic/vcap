# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../spec_helper'

require 'fileutils'
require 'nats/client'
require 'yajl/json_gem'
require 'vcap/common'
require 'vcap/logging'
require 'openssl'
require 'net/http'
require 'uri'
require "http/parser"
require "router/const"
require "router/router"
require 'pp'

class NatsServer

  TEST_PORT = 4228

  def initialize(uri="nats://localhost:#{TEST_PORT}", pid_file='/tmp/nats-router-tests.pid')
    @uri = URI.parse(uri)
    @pid_file = pid_file
  end

  def uri
    @uri.to_s
  end

  def server_pid
    @pid ||= File.read(@pid_file).chomp.to_i
  end

  def start_server
    return if NATS.server_running? @uri
    %x[ruby -S bundle exec nats-server -p #{@uri.port} -P #{@pid_file} -d 2> /dev/null]
    NATS.wait_for_server(@uri) # New version takes opt_timeout
  end

  def is_running?
    NATS.server_running? @uri
  end

  def kill_server
    if File.exists? @pid_file
      Process.kill('KILL', server_pid)
      FileUtils.rm_f(@pid_file)
    end
    sleep(0.5)
  end
end

class RouterServer

  PID_FILE    = '/tmp/router-test.pid'
  CONFIG_FILE = '/tmp/router-test.yml'
  LOG_FILE    = '/tmp/router-test.log'
  UNIX_SOCK   = '/tmp/router.sock' # unix socket between nginx and uls
  PORT        = 80                 # nginx listening port
  ULS_PORT    = 8082               # ULS listening port
  STATUS_PORT = 8081               # must be consistent with nginx config in dev_setup
  STATUS_USER = "admin"            # must be consistent with nginx config in dev_setup
  STATUS_PASSWD = "password"       # must be consistent with nginx config in dev_setup

  # We verify functionalities for the whole "router" (i.e. nginx + uls).
  # In all tests, when a client like to send a request to an test app,
  # it has to send to the port which nginx is listening.
  def initialize(nats_uri)
    @nats_uri = nats_uri
    log_info  = "logging:\n  level: debug\n  file: #{LOG_FILE}"
    @config = %Q{port: #{ULS_PORT}\ninet: 127.0.0.1\nsock: #{UNIX_SOCK}\nmbus: #{@nats_uri}\n#{log_info}\npid: #{PID_FILE}\nlocal_route: 127.0.0.1\nstatus:\n  port: #{STATUS_PORT}\n  user: #{STATUS_USER}\n  password: #{STATUS_PASSWD}}
  end

  def self.port
    PORT
  end

  def self.uls_port
    ULS_PORT
  end

  def self.sock
    UNIX_SOCK
  end

  def self.host
    '127.0.0.1'
  end

  def server_pid
    File.read(PID_FILE).chomp.to_i
  end

  def start_server
    return if is_running?

    # Write the config
    File.open(CONFIG_FILE, 'w') { |f| f.puts "#{@config}" }

    # Wipe old log file, but truncate so running tail works
    if (File.exists? LOG_FILE)
      File.truncate(LOG_FILE, 0)
      # %x[rm #{LOG_FILE}] if File.exists? LOG_FILE
    end

    server = File.expand_path(File.join(__FILE__, '../../../bin/router'))
    nats_timeout = File.expand_path(File.join(File.dirname(__FILE__), 'nats_timeout'))
    #pid = Process.fork { %x[#{server} -c #{CONFIG_FILE} 2> /dev/null] }
    pid = Process.fork { %x[ruby -r#{nats_timeout} #{server} -c #{CONFIG_FILE}] }
    Process.detach(pid)

    wait_for_server
  end

  def is_running?
    require 'socket'
    s = UNIXSocket.new(UNIX_SOCK)
    s.close
    return true
  rescue
    return false
  end

  def wait_for_server(max_wait = 5)
    start = Time.now
    while (Time.now - start < max_wait) # Wait max_wait seconds max
      break if is_running?
      sleep(0.2)
    end
  end

  def kill_server
    if File.exists? PID_FILE
      %x[kill -9 #{server_pid} 2> /dev/null]
      %x[rm #{PID_FILE}]
    end
    %x[rm #{CONFIG_FILE}] if File.exists? CONFIG_FILE
    sleep(0.2)
  end

  def get_healthz_by_nginx
    rbody = nil
    TCPSocket.open(RouterServer.host, RouterServer.port) {|rs|
      rs.send(healthz_request, 0)

      resp, rbody = parse_http_msg_from_socket(rs)
      resp.status_code.should == 200
    }
    rbody
  end

  def get_healthz
    get_stats("/healthz")
  end

  def get_varz
    JSON.parse(get_stats("/varz"), :symbolize_keys => true)
  end

  private

  def healthz_request
    "GET / HTTP/1.0\r\nUser-Agent: HTTP-Monitor/1.1\r\n\r\n"
  end

  def get_stats(stats_path)
    reply = json_request(@nats_uri, 'vcap.component.discover')

    credentials = reply[:credentials]
    host, port = reply[:host].split(":")

    req = Net::HTTP::Get.new(stats_path)
    req.basic_auth *credentials
    resp = Net::HTTP.new(host, port).start { |http| http.request(req) }
    resp.body
  end
end

# Encodes _data_ as json, decodes reply as json
def json_request(uri, subj, data=nil, timeout=1)
  reply = nil
  data_enc = data ? Yajl::Encoder.encode(data) : nil
  NATS.start(:uri => uri) do
    NATS.request(subj, data_enc) do |msg|
      reply = JSON.parse(msg, :symbolize_keys => true)
      NATS.stop
    end
    EM.add_timer(timeout) { NATS.stop }
  end

  reply
end

def parse_http_msg_from_socket(socket)
  parser = Http::Parser.new
  complete = false
  body = ''

  parser.on_body = proc do |chunk|
    body << chunk
  end

  parser.on_message_complete = proc do
    complete = true
    :stop
  end

  while not complete
    raw_data = socket.recv(1024)
    parser << raw_data
  end

  return parser, body
end

def parse_http_msg_from_buf(buf)
  parser = Http::Parser.new
  body = ''

  parser.on_body = proc do |chunk|
    body << chunk
  end
  parser.on_message_complete = proc do
    :stop
  end

  parser << buf

  return parser, body
end
