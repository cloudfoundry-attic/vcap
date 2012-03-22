# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/spec_helper'
require 'fileutils'

describe 'Router Functional Tests' do
  before :each do
    @dir = Dir.mktmpdir('router-test')
    nats_port = VCAP::grab_ephemeral_port
    @nats_server = VCAP::Spec::ForkedComponent::NatsServer.new(
      File.join(@dir, 'nats.pid'),
      nats_port,
      @dir)
    @nats_server.start
    @nats_server.running?.should be_true

    router_port = VCAP::grab_ephemeral_port
    @router = ForkedRouter.new(File.join(@dir, 'router.log'),
                               router_port,
                               nats_port,
                               @dir)
    # The router will only announce itself after it has subscribed to 'vcap.component.discover'.
    NATS.start(:uri => @nats_server.uri) do
      NATS.subscribe('vcap.component.announce') { NATS.stop }
      # Ensure that NATS has processed our subscribe from above before we start the router
      NATS.publish('xxx') { @router.start }
      EM.add_timer(5) { NATS.stop }
    end
    @router.is_running?.should be_true
  end

  after :each do
    @router.stop
    @router.is_running?.should be_false

    @nats_server.stop
    @nats_server.running?.should be_false
    FileUtils.remove_entry_secure(@dir)
  end

  it 'should respond to a discover message properly' do
    reply = json_request(@nats_server.uri, 'vcap.component.discover')
    reply.should_not be_nil
    reply[:type].should =~ /router/i
    reply.should have_key :uuid
    reply.should have_key :host
    reply.should have_key :start
    reply.should have_key :uptime
  end

  it 'should have proper http endpoints (/healthz, /varz)' do
    reply = json_request(@nats_server.uri, 'vcap.component.discover')
    reply.should_not be_nil

    credentials = reply[:credentials]
    credentials.should_not be_nil

    host, port = reply[:host].split(":")

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
    app = TestApp.new('router_test.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app)
    app.verify_registered('127.0.0.1', @router.port)
    app.stop
  end

  it 'should properly unregister an application endpoint' do
    # setup the "app"
    app = TestApp.new('router_test.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app)
    app.verify_registered('127.0.0.1', @router.port)
    dea.unregister_app(app)
    # We should be unregistered here..
    # Send out simple request and check request and response
    req = simple_http_request('router_test.cap.me', '/')
    # force context switch to avoid a race between unregister processing and
    # accepting new connections
    sleep(0.01)
    verify_vcap_404(req, '127.0.0.1', @router.port)
    app.stop
  end

  it 'should properly distibute messages between multiple backends' do
    num_apps = 10
    num_requests = 100
    dea = DummyDea.new(@nats_server.uri, '1234')

    apps = []
    for ii in (0...num_apps)
      app = TestApp.new('lb_test.vcap.me')
      dea.register_app(app)
      apps << app
    end

    req = simple_http_request('lb_test.vcap.me', '/')
    for ii in (0...num_requests)
      TCPSocket.open('127.0.0.1', @router.port) {|rs| rs.send(req, 0) }
    end
    sleep(0.25) # Wait here for requests to trip accept state

    app_sockets = apps.collect { |a| a.socket }
    ready = IO.select(app_sockets, nil, nil, 1)
    ready[0].should have(num_apps).items
    apps.each {|a| a.stop }
  end

  it 'should properly do sticky sessions' do
    num_apps = 10
    dea = DummyDea.new(@nats_server.uri, '1234')

    apps = []
    for ii in (0...num_apps)
      app = TestApp.new('sticky.vcap.me')
      dea.register_app(app)
      apps << app
    end

    vcap_id = app_socket = nil
    app_sockets = apps.collect { |a| a.socket }

    TCPSocket.open('127.0.0.1', @router.port) do |rs|
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
      TCPSocket.open('127.0.0.1', @router.port) do |rs|
        rs.send(sticky_request, 0)
      end
    end

    ready = IO.select(app_sockets, nil, nil, 1)
    ready[0].should have(1).items
    app_socket.should == ready[0].first

    for app in apps
      dea.unregister_app(app)
    end

    # force context switch to avoid a race between unregister processing and
    # accepting new connections
    sleep(0.01)
    # Check that is is gone
    verify_vcap_404(STICKY_REQUEST, '127.0.0.1', @router.port)

    apps.each {|a| a.stop }
  end

  it 'should properly exit when NATS fails to reconnect' do
    @nats_server.stop
    @nats_server.running?.should be_false
    sleep(0.5)
    @router.is_running?.should be_false
  end

  it 'should not start with nats not running' do
    @nats_server.stop
    @nats_server.running?.should be_false
    @router.stop
    @router.is_running?.should be_false

    @router.start
    sleep(0.5)
    @router.is_running?.should be_false
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
      response = rs.read(VCAP_NOT_FOUND.bytesize)
      response.should == VCAP_NOT_FOUND
    end
  end
end
