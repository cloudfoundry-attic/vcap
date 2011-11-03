# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/spec_helper'
require "base64"

describe 'Router Functional Tests' do
  before :each do
    @nats_server = NatsServer.new
    @nats_server.start_server
    @nats_server.is_running?.should be_true

    @router = RouterServer.new(@nats_server.uri)
    # The router will only announce itself after it has subscribed to 'vcap.component.discover'.
    NATS.start(:uri => @nats_server.uri) do
      NATS.subscribe('vcap.component.announce') { NATS.stop }
      # Ensure that NATS has processed our subscribe from above before we start the router
      NATS.publish('xxx') { @router.start_server }
      EM.add_timer(5) { NATS.stop }
    end
    @router.is_running?.should be_true
  end

  after :each do
    @router.kill_server
    @router.is_running?.should be_false

    @nats_server.kill_server
    @nats_server.is_running?.should be_false
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

    varz = get_varz()
    varz[:requests].should be_a_kind_of(Integer)
    varz[:bad_requests].should be_a_kind_of(Integer)
    varz[:client_connections].should be_a_kind_of(Integer)
    varz[:type].should =~ /router/i
  end

  it 'should get health status via nginx' do
    body = get_healthz()
    body.should =~ /ok/i
  end

  it 'should properly register an application endpoint' do
    # setup the "app"
    app = TestApp.new('router_test.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app)
    app.verify_registered('127.0.0.1', RouterServer.port)
    app.stop
  end

  it 'should properly unregister an application endpoint' do
    # setup the "app"
    app = TestApp.new('router_test.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app)
    app.verify_registered('127.0.0.1', RouterServer.port)
    dea.unregister_app(app)
    # We should be unregistered here..
    # Send out simple request and check request and response
    req = simple_http_request('router_test.cap.me', '/')
    verify_vcap_404(req, '127.0.0.1', RouterServer.port)
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
    app_sockets = apps.collect { |a| a.socket }

    results = send_requests_to_apps("127.0.0.1", RouterServer.port,
                                    req, num_requests, app_sockets,
                                    FOO_HTTP_RESPONSE)
    results.should have(num_apps).items
    recv_requests = 0
    results.each { |entry|
      recv_requests += entry[:counter]
    }
    recv_requests.should == num_requests
    apps.each {|a| a.stop }

  end

  it 'should get correct statistics' do
    num_apps = 10
    num_requests = 1000
    dea = DummyDea.new(@nats_server.uri, '1234')

    apps = []
    for ii in (0...num_apps)
      app = TestApp.new('lb_test.vcap.me')
      dea.register_app(app, {"component" => "test#{ii}", "runtime" => "ruby"})
      apps << app
    end

    # Before we count the statistics, we should restart nginx worker
    # to cleanup unsynced stats.
    %x[ps -ef|grep "nginx: master process"|grep -v grep|awk '{print $2}'|xargs sudo kill -HUP 2> /dev/null]

    sleep(2)

    req = simple_http_request('lb_test.vcap.me', '/')
    app_sockets = apps.collect { |a| a.socket }

    results = send_requests_to_apps("127.0.0.1", RouterServer.port,
                                    req, num_requests, app_sockets,
                                    FOO_HTTP_RESPONSE)
    # Verify all apps get request and the totally number is correct
    results.should have(num_apps).items
    recv_requests = 0
    results.each { |entry|
      recv_requests += entry[:counter]
    }
    recv_requests.should == num_requests
    for app in apps
      dea.unregister_app(app)
    end

    apps.each {|a| a.stop }

    varz = get_varz()
    varz[:requests].should be_a_kind_of(Integer)
    varz[:client_connections].should be_a_kind_of(Integer)
    varz[:type].should =~ /router/i

    # Requests are collected exactly the same number as we received
    # since each of them triggers a location query to uls
    varz[:requests].should == num_requests

    # send_requests_to_apps is sequentially sending out num_requests requests,
    # so each response of a outstanding request updates its previous one
    # and we are sure the status of the last request is still in nginx
    varz[:responses_2xx].should == (num_requests - 1)

    comp_reqs = comp_resps_2xx = 0
    # Verify the statistics for each type of request tags
    for ii in (0...num_apps)
       comp_reqs += varz[:tags][:component]["test#{ii}".to_sym][:requests]
       comp_resps_2xx += varz[:tags][:component]["test#{ii}".to_sym][:responses_2xx]
    end
    comp_reqs.should == num_requests
    comp_resps_2xx.should == num_requests - 1
    varz[:tags][:runtime][:ruby][:requests].should == num_requests
    varz[:tags][:runtime][:ruby][:responses_2xx].should == num_requests - 1

    # Send an monitor request to nginx to syncup the left stats
    body = get_healthz()
    body.should =~ /ok/i

    varz = get_varz()
    comp_resps_2xx = 0
    # Verify the statistics for each type of request tags
    for ii in (0...num_apps)
       comp_resps_2xx += varz[:tags][:component]["test#{ii}".to_sym][:responses_2xx]
    end
    comp_resps_2xx.should == num_requests
    varz[:tags][:runtime][:ruby][:responses_2xx].should == num_requests
  end

  it 'should properly do sticky sessions' do
    num_apps = 10
    num_requests = 100
    dea = DummyDea.new(@nats_server.uri, '1234')

    apps = []
    for ii in (0...num_apps)
      app = TestApp.new('sticky.vcap.me')
      dea.register_app(app)
      apps << app
    end

    vcap_id = app_socket = nil
    app_sockets = apps.collect { |a| a.socket }

    TCPSocket.open('127.0.0.1', RouterServer.port) do |rs|
      rs.send(STICKY_REQUEST, 0)
      ready = IO.select(app_sockets, nil, nil, 1)
      ready[0].should have(1).items
      app_socket = ready[0].first
      ss = app_socket.accept_nonblock

      smsg, sbody = parse_http_msg_from_buf(STICKY_REQUEST)
      rmsg, rbody = parse_http_msg_from_socket(ss)
      validate_recv_msg_against_send(smsg, sbody, rmsg, rbody).should == true

      ss.send(STICKY_RESPONSE, 0)
      smsg, sbody = parse_http_msg_from_buf(STICKY_RESPONSE)
      rmsg, rbody = parse_http_msg_from_socket(rs)
      validate_recv_msg_against_send(smsg, sbody, rmsg, rbody).should == true
      rmsg.headers["Set-Cookie"] =~ /\s*__VCAP_ID__=([^,;]+)/
      (vcap_id = $1).should be
    end

    cookie = "__VCAP_ID__=#{vcap_id}"
    sticky_request = simple_sticky_request('sticky.vcap.me', '/sticky', cookie)

    results = send_requests_to_apps("127.0.0.1", RouterServer.port,
                                    sticky_request, num_requests, app_sockets,
                                    FOO_HTTP_RESPONSE)
    # Now fire off requests, all should go to same socket as first
    results.should have(1).items
    results[0][:app_socket].should == app_socket
    recv_requests = 0
    results.each { |entry|
      recv_requests += entry[:counter]
    }
    recv_requests.should == num_requests

    for app in apps
      dea.unregister_app(app)
    end

    # Check that it is gone
    verify_vcap_404(STICKY_REQUEST, '127.0.0.1', RouterServer.port)

    apps.each {|a| a.stop }
  end

  it 'should add vcap trace headers' do
    app = TestApp.new('trace.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app, {"component" => "trace", "runtime" => "ruby"})

    resp = app.get_trace_header("127.0.0.1", RouterServer.port)
    resp.headers["X-Vcap-Backend"].should_not be_nil
    h, p = resp.headers["X-Vcap-Backend"].split(":")
    p.to_i.should == app.port.to_i

    dea.unregister_app(app)

    app.stop
  end

  it 'should properly exit when NATS fails to reconnect' do
    @nats_server.kill_server
    @nats_server.is_running?.should be_false
    sleep(0.5)
    @router.is_running?.should be_false
  end

  it 'should not start with nats not running' do
    @nats_server.kill_server
    @nats_server.is_running?.should be_false
    @router.kill_server
    @router.is_running?.should be_false

    @router.start_server
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
      rs.send(healthz_request(Base64.encode64(credentials*':').strip), 0)

      resp, rbody = parse_http_msg_from_socket(rs)
      resp.status_code.should == 200
    }
    rbody
  end

end
