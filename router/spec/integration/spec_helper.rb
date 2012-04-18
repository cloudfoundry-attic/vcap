# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../lib/spec_helper'

# HTTP REQUESTS / RESPONSES
FOO_HTTP_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 31\r\nConnection: keep-alive\r\nServer: thin 1.2.7 codename No Hup\r\n\r\n<h1>Hello from the Clouds!</h1>"

VCAP_NOT_FOUND = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\nVCAP ROUTER: 404 - DESTINATION NOT FOUND\r\n"

STICKY_REQUEST = "GET /sticky HTTP/1.1\r\nHost: sticky.vcap.me\r\nConnection: keep-alive\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n\r\n"

STICKY_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 242\r\nSet-Cookie: _session_id=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nSet-Cookie: JSESSIONID=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nConnection: keep-alive\r\nServer: thin 1.2.7 codename No Hup\r\n\r\n<h1>Hello from the Cookie Monster! via: 10.0.1.222:35267</h1><h2>session = be009e56c7be0e855d951a3b49e288c98aa36ede</h2><h4>Cookies set: _session_id, JSESSIONID<h4>Note: Trigger new sticky session cookie name via ?ss=NAME appended to URL</h4>"

TRACE_KEY = "222" # Should be consistent with dev_setup deployment configuration

def simple_http_request(host, path, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nUser-Agent: curl/7.19.7 (i486-pc-linux-gnu) libcurl/7.19.7 OpenSSL/0.9.8k zlib/1.2.3.3 libidn/1.15\r\nHost: #{host}\r\nAccept: */*\r\nContent-Length: 11\r\n\r\nhello world"
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
    elsif hdr == "Host"
      # nginx will rewrite uppercase host to lowercase
      val.downcase.should == recv_msg.headers[hdr]
    else
      val.should == recv_msg.headers[hdr]
    end
  end

  return true
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

def verify_vcap_404(req, router_host, router_port)
  TCPSocket.open(router_host, router_port) do |rs|
    rs.send(req, 0)
    rmsg, rbody = parse_http_msg_from_socket(rs)
    rmsg.status_code.should == 404
  end
end

def get_varz
  reply = json_request(@nats_server.uri, 'vcap.component.discover')
  reply.should_not be_nil

  credentials = reply[:credentials]
  credentials.should_not be_nil

  host, port = reply[:host].split(":")

  varz_req = Net::HTTP::Get.new("/varz")
  varz_req.basic_auth *credentials
  varz_resp = Net::HTTP.new(host, port).start { |http| http.request(varz_req) }
  varz = JSON.parse(varz_resp.body, :symbolize_keys => true)
  varz
end

def get_healthz
  reply = json_request(@nats_server.uri, 'vcap.component.discover')
  reply.should_not be_nil

  credentials = reply[:credentials]
  credentials.should_not be_nil

  rbody = nil
  TCPSocket.open("127.0.0.1", RouterServer.port) {|rs|
    rs.send(healthz_request, 0)

    resp, rbody = parse_http_msg_from_socket(rs)
    resp.status_code.should == 200
  }
  rbody
end

def simple_sticky_request(host, path, cookie, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nHost: #{host}\r\nConnection: keep-alive\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\nCookie: #{cookie}\r\n\r\n"
end

def healthz_request
  "GET / HTTP/1.0\r\nUser-Agent: HTTP-Monitor/1.1\r\n\r\n"
end

def trace_request(trace_key)
  "GET /trace HTTP/1.1\r\nHost: trace.vcap.me\r\nConnection: keep-alive\r\nX-Vcap-Trace: #{trace_key}\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nUser-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.237 Safari/534.10\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\n\r\n"
end

def send_http_request(ip, port, req)
  status, body = nil, nil
  TCPSocket.open(ip, port) do |rs|
    rs.send(req, 0)
    rs.close_write
    result = rs.read
    parser, body = parse_http_msg_from_buf(result)
    status = parser.status_code
  end
  [ status, body ]
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

def verify_results_by_request(results, num_requests)
  recv_requests = 0
  results.each { |entry|
    recv_requests += entry[:counter]
  }
  recv_requests.should == num_requests
end

def verify_results_by_socket(results, app_socket)
  results.should have(1).items
  results[0][:app_socket].should == app_socket
end

def verify_results(results, app_socket, num_requests)
  verify_results_by_request(results, num_requests)
  verify_results_by_socket(results, app_socket)
end

module Integration

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

    def new_app_socket
      app_socket = TCPServer.new('127.0.0.1', 0)
      app_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      Socket.do_not_reverse_lookup = true
      app_port = app_socket.addr[1]
      [app_socket, app_port]
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
        # verify both original uri and uppercase uri
        verify_path_registered(uri, '/', router_host, router_port)
        verify_path_registered(uri.upcase, '/', router_host, router_port)
      end
    end

    def get_trace_header(router_host, router_port, trace_key)
      req = trace_request(trace_key)
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
end
