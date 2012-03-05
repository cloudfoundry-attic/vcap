# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../lib/spec_helper'

# HTTP REQUESTS / RESPONSES
FOO_HTTP_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 31\r\nConnection: keep-alive\r\nServer: thin 1.2.7 codename No Hup\r\n\r\n<h1>Hello from the Clouds!</h1>"

STICKY_HTTP_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Length: 11\r\nSet-Cookie: _session_id=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nSet-Cookie: JSESSIONID=be009e56c7be0e855d951a3b49e288c98aa36ede; path=/\r\nConnection: keep-alive\r\n\r\nhello world"

TRACE_KEY = "222" # Should be consistent with dev_setup deployment configuration

def simple_http_request(host, path, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nHost: #{host}\r\nAccept: */*\r\nContent-Length: 11\r\n\r\nhello world"
end

def simple_sticky_request(host, path, cookie, http_version='1.1')
  "GET #{path} HTTP/#{http_version}\r\nHost: #{host}\r\nConnection: keep-alive\r\nCookie: #{cookie}\r\n\r\n"
end

def trace_request(trace_key)
  "GET /trace HTTP/1.1\r\nHost: trace.vcap.me\r\nConnection: keep-alive\r\nX-Vcap-Trace: #{trace_key}\r\n\r\n"
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

def verify_vcap_404(req, router_host, router_port)
  TCPSocket.open(router_host, router_port) do |rs|
    rs.send(req, 0)
    rmsg, rbody = parse_http_msg_from_socket(rs)
    rmsg.status_code.should == 404
  end
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
    def verify_registered
      for uri in @uris
        verify_path_registered(uri, '/', RouterServer.host, RouterServer.port)
      end
    end

    def verify_unregistered
      for uri in @uris
        verify_path_unregistered(uri, '/', RouterServer.host, RouterServer.port)
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

    def verify_path_unregistered(host, path, router_host, router_port)
      req = simple_http_request(host, path)
      verify_vcap_404(req, router_host, router_port)
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
