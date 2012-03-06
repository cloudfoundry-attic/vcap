# Copyright (c) 2009-2012 VMware, Inc.
require File.dirname(__FILE__) + '/../spec_helper'

require 'fileutils'
require 'nats/client'
require 'yajl/json_gem'
require 'openssl'
require 'net/http'
require 'uri'
require 'tempfile'
require 'yaml'
require 'vcap/spec/forked_component/nats_server'

require 'pp'

# Full path to the Ruby we are running under as configured when it was
# compiled, so if you have moved or copied it, funny things might happen
def current_ruby
  File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
end

class ForkedRouter < VCAP::Spec::ForkedComponent::Base

  ROUTER_PATH = File.expand_path('../../../bin/router', __FILE__)

  attr_reader :port
  def initialize(log_file, port, nats_port, router_dir)
    @port, @nats_port, @log_file = port, nats_port, log_file
    pid_file = File.join(router_dir, 'router.pid')
    config = {
      'port' => port,
      'inet' => '127.0.0.1',
      'mbus' => "nats://127.0.0.1:#{nats_port}",
      'logging' => { 'level' => 'debug' },
      'pid' => pid_file,
    }

    config_file = File.join(router_dir, 'router.yml')
    nats_timeout = File.expand_path(File.join(File.dirname(__FILE__), 'nats_timeout'))

    # Write the config
    File.open(config_file, 'w') { |f| YAML.dump config, f }
    cmd = "#{current_ruby} -r#{nats_timeout} #{ROUTER_PATH} -c #{config_file}"

    super(cmd, 'router', router_dir, pid_file)
  end

  def start
    return if is_running?
    super
  end

  def is_running?
    require 'socket'
    s = TCPSocket.new('localhost', @port)
    s.close
    return true
  rescue
    return false
  end
end


# HTTP REQUESTS / RESPONSES

FOO_HTTP_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 53\r\nConnection: keep-alive\r\nServer: thin 1.2.7 codename No Hup\r\n\r\n<h1>Hello from the Clouds!</h1>"

VCAP_NOT_FOUND = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\nVCAP ROUTER: 404 - DESTINATION NOT FOUND\r\n"

STICKY_REQUEST = "GET /sticky HTTP/1.1\r\nHost: sticky.vcap.me\r\nConnection: keep-alive\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n\r\n"

STICKY_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 242\r\nSet-Cookie: _session_id=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nSet-Cookie: JSESSIONID=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nConnection: keep-alive\r\nServer: thin 1.2.7 codename No Hup\r\n\r\n<h1>Hello from the Cookie Monster! via: 10.0.1.222:35267</h1><h2>session = be009e56c7be0e855d951a3b49e288c98aa36ede</h2><h4>Cookies set: _session_id, JSESSIONID<h4>Note: Trigger new sticky session cookie name via ?ss=NAME appended to URL</h4>"


def simple_http_request(host, path, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nUser-Agent: curl/7.19.7 (i486-pc-linux-gnu) libcurl/7.19.7 OpenSSL/0.9.8k zlib/1.2.3.3 libidn/1.15\r\nHost: #{host}\r\nAccept: */*\r\n\r\n"
end

def simple_sticky_request(host, path, cookie, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nHost: #{host}\r\nConnection: keep-alive\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\nCookie: #{cookie}\r\n\r\n"
end

def new_app_socket
  app_socket = TCPServer.new('127.0.0.1', 0)
  app_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
  Socket.do_not_reverse_lookup = true
  app_port = app_socket.addr[1]
  [app_socket, app_port]
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

  private

  def verify_path_registered(host, path, router_host, router_port)
    req = simple_http_request(host, path)
    # Send out simple request and check request and response
    TCPSocket.open(router_host, router_port) do |rs|
      rs.send(req, 0)
      IO.select([@socket], nil, nil, 2) # 2 secs timeout
      ss = @socket.accept_nonblock
      req_received = ss.recv(req.bytesize)
      req_received.should == req
      # Send a response back..
      ss.send(FOO_HTTP_RESPONSE, 0)
      response = rs.read(FOO_HTTP_RESPONSE.bytesize)
      response.should == FOO_HTTP_RESPONSE
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

  def reg_hash_for_app(app)
    { :dea  => @dea_id,
      :host => @host,
      :port => app.port,
      :uris => app.uris
    }
  end

  def register_app(app)
    NATS.start(:uri => @nats_uri) do
      NATS.publish('router.register', reg_hash_for_app(app).to_json) { NATS.stop }
    end
  end

  def unregister_app(app)
    NATS.start(:uri => @nats_uri) do
      NATS.publish('router.unregister', reg_hash_for_app(app).to_json) { NATS.stop }
    end
  end
end
