# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../spec_helper'

require 'fileutils'
require 'nats/client'
require 'yajl/json_gem'
require 'vcap/common'
require 'openssl'
require 'net/http'
require 'uri'
require "http/parser"

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
  STATUS_PORT = 8081               # must be consistent with nginx config
  STATUS_USER = "admin"
  STATUS_PASSWD = "password"

  # We verify functionalities for the whole "router" (i.e. nginx + uls).
  # In all tests, when a client like to send a request to an test app,
  # it has to send to the port which nginx is listening.
  def initialize(nats_uri)
    mbus      = "mbus: #{nats_uri}"
    log_info  = "logging:\n  level: debug\n  file: #{LOG_FILE}"
    @config = %Q{sock: #{UNIX_SOCK}\n#{mbus}\n#{log_info}\npid: #{PID_FILE}\nlocal_route: 127.0.0.1\nstatus:\n  port: #{STATUS_PORT}\n  user: #{STATUS_USER}\n  password: #{STATUS_PASSWD}}
  end

  def self.port
    PORT
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
    pid = Process.fork { %x[ruby -r#{nats_timeout} #{server} -c #{CONFIG_FILE} 2> /dev/null] }
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
end
5

# HTTP REQUESTS / RESPONSES

FOO_HTTP_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 31\r\nConnection: keep-alive\r\nServer: thin 1.2.7 codename No Hup\r\n\r\n<h1>Hello from the Clouds!</h1>"

VCAP_NOT_FOUND = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\nVCAP ROUTER: 404 - DESTINATION NOT FOUND\r\n"

STICKY_REQUEST = "GET /sticky HTTP/1.1\r\nHost: sticky.vcap.me\r\nConnection: keep-alive\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n\r\n"

STICKY_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 242\r\nSet-Cookie: _session_id=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nSet-Cookie: JSESSIONID=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nConnection: keep-alive\r\nServer: thin 1.2.7 codename No Hup\r\n\r\n<h1>Hello from the Cookie Monster! via: 10.0.1.222:35267</h1><h2>session = be009e56c7be0e855d951a3b49e288c98aa36ede</h2><h4>Cookies set: _session_id, JSESSIONID<h4>Note: Trigger new sticky session cookie name via ?ss=NAME appended to URL</h4>"

def simple_http_request(host, path, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nUser-Agent: curl/7.19.7 (i486-pc-linux-gnu) libcurl/7.19.7 OpenSSL/0.9.8k zlib/1.2.3.3 libidn/1.15\r\nHost: #{host}\r\nAccept: */*\r\nContent-Length: 11\r\n\r\nhello world"
end

def simple_sticky_request(host, path, cookie, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nHost: #{host}\r\nConnection: keep-alive\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\nCookie: #{cookie}\r\n\r\n"
end

def healthz_request(auth)
  "GET / HTTP/1.0\r\nAuthorization: Basic #{auth}\r\nUser-Agent: HTTP-Monitor/1.1\r\n\r\n"
end

def trace_request(trace_key)
  "GET /trace HTTP/1.1\r\nHost: trace.vcap.me\r\nConnection: keep-alive\r\nX-Vcap-Trace: #{trace_key}\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n\r\n"
end

def new_app_socket
  app_socket = TCPServer.new('127.0.0.1', 0)
  app_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
  Socket.do_not_reverse_lookup = true
  app_port = app_socket.addr[1]
  [app_socket, app_port]
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

def validate_recv_msg_against_send(send_msg, send_body, recv_msg, recv_body)
  recv_body.should == send_body

  recv_msg.http_method.should == send_msg.http_method
  recv_msg.request_url.should == send_msg.request_url
  recv_msg.status_code.should == send_msg.status_code

  # Verify most of the headers are preserved when traversing the "router"
  send_msg.headers.each do |hdr, val|
    # Skip the headers nginx will rewrite
    if (hdr == "Server" or hdr == "Date" or hdr == "Connection") then next end

    if hdr == "Set-Cookie"
      # Http Parser concatenates all Set-Cookie headers together
      val.split(',').each do |cookie|
        (recv_msg.headers["Set-Cookie"].include? cookie).should == true
      end
    else
      val.should == recv_msg.headers[hdr]
    end
  end

  return true
end

def send_requests_to_apps(ip, port, req, num_requests, app_sockets, resp)
  results = []
  for i in (0...num_requests)
    TCPSocket.open(ip, port) {|rs|
      rs.send(req, 0)
      ready = IO.select(app_sockets, nil, nil, 1)
      ready[0].should have(1).items
      app_socket = ready[0].first
      ss = app_socket.accept_nonblock
      # Drain the socket
      parse_http_msg_from_socket(ss)
      # Send a response back to client to emulate a full req/resp cycle
      # to avoid nginx 499 error
      ss.send(resp, 0)

      found = false
      results.each { |entry|
        if (entry[:app_socket] == app_socket)
          entry[:counter] += 1
          found = true
          break
        end
      }
      if not found
        entry = {
          :app_socket => app_socket,
          :counter => 1
        }
        results << entry
      end
    }
  end
  results
end

class TestApp
  class UsageError < StandardError; end

  attr_reader :host, :port, :uris, :socket

  def initialize(*uris)
    @uris = uris
    @port = nil
    @socket = nil
    start
  end

  def start
    raise UsageError, "Already started" if @socket
    sock, port = new_app_socket
    @socket = sock
    @port = port
  end

  def stop
    raise UsageError, "Already stopped" if !@socket
    @socket.close
    @socket = nil
    @port = nil
  end
  # Simple check that the app can be queried via the router
  def verify_registered(router_host, router_port)
    for uri in @uris
      verify_path_registered(uri, '/', router_host, router_port)
    end
  end

  def get_trace_header(router_host, router_port)
    req = trace_request("222")  # Make sure consistent with deployment config
    # Send out simple request and check request and response
    TCPSocket.open(router_host, router_port) do |rs|
      rs.send(req, 0)
      IO.select([@socket], nil, nil, 2) # 2 secs timeout
      ss = @socket.accept_nonblock

      # Send a response back..
      ss.send(FOO_HTTP_RESPONSE, 0)
      rmsg, rbody = parse_http_msg_from_socket(rs)
      ss.close
      return rmsg
    end
  end

  private

  def verify_path_registered(host, path, router_host, router_port)
    req = simple_http_request(host, path)
    # Send out simple request and check request and response
    TCPSocket.open(router_host, router_port) do |rs|
      rs.send(req, 0)
      IO.select([@socket], nil, nil, 2) # 2 secs timeout
      ss = @socket.accept_nonblock

      smsg, sbody = parse_http_msg_from_buf(req)
      rmsg, rbody = parse_http_msg_from_socket(ss)
      validate_recv_msg_against_send(smsg, sbody, rmsg, rbody).should == true

      # Send a response back..
      ss.send(FOO_HTTP_RESPONSE, 0)
      smsg, sbody = parse_http_msg_from_buf(FOO_HTTP_RESPONSE)
      rmsg, rbody = parse_http_msg_from_socket(rs)
      validate_recv_msg_against_send(smsg, sbody, rmsg, rbody).should == true

      ss.close
    end
  end

end

class DummyDea

  attr_reader :nats_uri, :dea_id

  def initialize(nats_uri, dea_id, host='127.0.0.1')
    @nats_uri = nats_uri
    @dea_id = dea_id
    @host = host
  end

  def reg_hash_for_app(app, tags = {})
    { :dea  => @dea_id,
      :host => @host,
      :port => app.port,
      :uris => app.uris,
      :tags => tags
    }
  end

  def register_app(app, tags = {})
    NATS.start(:uri => @nats_uri) do
      NATS.publish('router.register', reg_hash_for_app(app, tags).to_json) { NATS.stop }
    end
  end

  def unregister_app(app)
    NATS.start(:uri => @nats_uri) do
      NATS.publish('router.unregister', reg_hash_for_app(app).to_json) { NATS.stop }
    end
  end
end
