# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/spec_helper'

describe 'Router Functional Tests' do

  before :all do
    @nats_server = NatsServer.new
    @router = RouterServer.new(@nats_server.uri)
  end

  after :all  do
    @router.kill_server
    @router.is_running?.should be_false

    @nats_server.kill_server
    @nats_server.is_running?.should be_false
  end

  it 'should start nats correctly' do
    @nats_server.start_server
    @nats_server.is_running?.should be_true
  end

  it 'should start router correctly' do
    # This avoids a race in the next test ('should respond to a discover message properly')
    # between when we issue a request and when the router has subscribed. (The router will
    # only announce itself after it has subscribed to 'vcap.component.discover'.)
    NATS.start(:uri => @nats_server.uri) do
      NATS.subscribe('vcap.component.announce') { NATS.stop }
      # Ensure that NATS has processed our subscribe from above before we start the router
      NATS.publish('xxx') { @router.start_server }
      EM.add_timer(5) { NATS.stop }
    end
    @router.is_running?.should be_true
  end

  it 'should respond to a discover message properly' do
    reply = nil
    NATS.start(:uri => @nats_server.uri) do
      NATS.request('vcap.component.discover') do |msg|
        reply = JSON.parse(msg, :symbolize_keys => true)
        NATS.stop
      end
      EM.add_timer(1) { NATS.stop }
    end
    reply[:type].should =~ /router/i
    reply.should have_key :uuid
    reply.should have_key :host
    reply.should have_key :start
    reply.should have_key :uptime
    ROUTER_HOST = reply[:host]
  end

  it 'should have proper http endpoints (/healthz, /varz)' do
    credentials = nil
    NATS.start(:uri => @nats_server.uri) do
      NATS.request('vcap.component.discover') do |msg|
        reply = JSON.parse(msg, :symbolize_keys => true)
        credentials = reply[:credentials]
        NATS.stop
      end
      EM.add_timer(1) { NATS.stop }
    end

    host, port = ROUTER_HOST.split(":")

    healthz_req = Net::HTTP::Get.new("/healthz")
    healthz_req.basic_auth *credentials
    healthz_resp = Net::HTTP.new(host, port).start { |http| http.request(healthz_req) }
    healthz_resp.body.should =~ /ok/i

    varz_req = Net::HTTP::Get.new("/varz")
    varz_req.basic_auth *credentials
    varz_resp = Net::HTTP.new(host, port).start { |http| http.request(varz_req) }
    varz = JSON.parse(varz_resp.body, :symbolize_keys => true)
    varz[:requests].should be_a_kind_of(Integer)
    varz[:bad_requests].should be_a_kind_of(Integer)
    varz[:client_connections].should be_a_kind_of(Integer)
    varz[:type].should =~ /router/i
  end

  it 'should properly register an application endpoint' do
    # setup the "app"
    app_socket, app_port = new_app_socket

    r = {:dea => '1234', :host => '127.0.0.1', :port => app_port, :uris => ['router_test.vcap.me']}

    NATS.start(:uri => @nats_server.uri) do
      # Registration Message
      NATS.publish('router.register', r.to_json) {  NATS.stop }
    end

    req = simple_http_request('router_test.vcap.me', '/')

    # We should be registered here..
    # Send out simple request and check request and response
    TCPSocket.open('127.0.0.1', RouterServer.port) do |rs|
      rs.send(req, 0)
      IO.select([app_socket], nil, nil, 2) # 2 secs timeout
      ss = app_socket.accept_nonblock
      req_received = ss.recv(req.bytesize)
      req_received.should == req
      # Send a response back..
      ss.send(FOO_HTTP_RESPONSE, 0)
      response = rs.read(FOO_HTTP_RESPONSE.bytesize)
      response.should == FOO_HTTP_RESPONSE
      ss.close
    end
    app_socket.close
    APP_PORT = app_port
  end

  it 'should properly unregister an application endpoint' do
    r = {:dea => '1234', :host => '127.0.0.1', :port => APP_PORT, :uris => ['router_test.vcap.me']}
    req = simple_http_request('router_test.vcap.me', '/')
    NATS.start(:uri => @nats_server.uri) do
      # Unregistration Message
      NATS.publish('router.unregister', r.to_json) {  NATS.stop }
    end

    # We should be unregistered here..
    # Send out simple request and check request and response
    TCPSocket.open('127.0.0.1', RouterServer.port) do |rs|
      rs.send(req, 0)
      response = rs.read(VCAP_NOT_FOUND.bytesize)
      response.should == VCAP_NOT_FOUND
    end
  end

  it 'should properly distibute messages between multiple backends' do

    NUM_APPS = 10
    NUM_REQUESTS = 100

    apps = []

    r = {:dea => '1234', :host => '127.0.0.1', :port => 0, :uris => ['lb_test.vcap.me']}

    NATS.start(:uri => @nats_server.uri) do
      # Create 10 backends
      (0...NUM_APPS).each do |i|
        apps << new_app_socket
        # Registration Message
        r[:port] = apps[i][1]
        NATS.publish('router.register', r.to_json)
      end
      NATS.publish('done') { NATS.stop } # Flush through nats
    end

    req = simple_http_request('lb_test.vcap.me', '/')

    app_sockets = apps.collect { |a| a[0] }

    (0...NUM_REQUESTS).each do
      TCPSocket.open('127.0.0.1', RouterServer.port) do |rs|
      rs.send(req, 0)
      end
    end
    sleep(0.25) # Wait here for requests to trip accept state
    ready = IO.select(app_sockets, nil, nil, 1)
    ready[0].should have(NUM_APPS).items
    app_sockets.each { |s| s.close }

    # Unregister
    NATS.start(:uri => @nats_server.uri) do
      (0...NUM_APPS).each do |i|
        r[:port] = apps[i][1]
        NATS.publish('router.unregister', r.to_json)
      end
      NATS.publish('done') { NATS.stop } # Flush through nats
    end

  end

  it 'should properly do sticky sessions' do

    apps = []
    r = {:dea => '1234', :host => '127.0.0.1', :port => 0, :uris => ['sticky.vcap.me']}

    NATS.start(:uri => @nats_server.uri) do
      # Create 10 backends
      (0...NUM_APPS).each do |i|
        apps << new_app_socket
        # Registration Message
        r[:port] = apps[i][1]
        NATS.publish('router.register', r.to_json)
      end
      NATS.publish('done') { NATS.stop } # Flush through nats
    end

    vcap_id = app_socket = nil
    app_sockets = apps.collect { |a| a[0] }

    TCPSocket.open('127.0.0.1', RouterServer.port) do |rs|
      rs.send(STICKY_REQUEST, 0)
      ready = IO.select(app_sockets, nil, nil, 1)
      ready[0].should have(1).items
      app_socket = ready[0].first
      ss = app_socket.accept_nonblock
      req_received = ss.recv(STICKY_REQUEST.bytesize)
      req_received.should == STICKY_REQUEST
      # Send a response back.. This will set the sticky session
      ss.send(STICKY_RESPONSE, 0)
      response = rs.read(STICKY_RESPONSE.bytesize)
      # Make sure the __VCAP_ID__ has been set
      response =~ /Set-Cookie:\s*__VCAP_ID__=([^;]+);/
      (vcap_id = $1).should be
    end

    cookie = "__VCAP_ID__=#{vcap_id}"
    sticky_request = simple_sticky_request('sticky.vcap.me', '/sticky', cookie)

    # Now fire off requests, all should go to same socket as first
    (0...5).each do
      TCPSocket.open('127.0.0.1', RouterServer.port) do |rs|
        rs.send(sticky_request, 0)
      end
    end

    ready = IO.select(app_sockets, nil, nil, 1)
    ready[0].should have(1).items
    app_socket.should == ready[0].first

    # Unregister (FIXME) Fails DRY
    NATS.start(:uri => @nats_server.uri) do
      (0...NUM_APPS).each do |i|
        r[:port] = apps[i][1]
        NATS.publish('router.unregister', r.to_json)
      end
      NATS.publish('done') { NATS.stop } # Flush through nats
    end

    # Check that is is gone
    TCPSocket.open('127.0.0.1', RouterServer.port) do |rs|
      rs.send(STICKY_REQUEST, 0)
      response = rs.read(VCAP_NOT_FOUND.bytesize)
      response.should == VCAP_NOT_FOUND
    end

    app_sockets.each { |s| s.close }

  end

  it 'should properly exit when NATS fails to reconnect' do
    @nats_server.kill_server
    @nats_server.is_running?.should be_false
    sleep(0.5)
    @router.is_running?.should be_false
  end

  it 'should not start with nats not running' do
    @nats_server.is_running?.should be_false
    @router.start_server
    sleep(0.5)
    @router.is_running?.should be_false
  end

  # If you run test below here, need to restart NATS.
end
