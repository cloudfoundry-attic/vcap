# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/spec_helper'
require "base64"

describe 'Router Integration Tests (require nginx running)' do
  include Integration

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

  it 'should properly distribute messages between multiple backends' do
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
    num_requests = 100
    dea = DummyDea.new(@nats_server.uri, '1234')

    apps = []
    for ii in (0...num_apps)
      app = TestApp.new('lb_test.vcap.me')
      dea.register_app(app, {"component" => "test#{ii}", "runtime" => "ruby"})
      apps << app
    end

    # Before we count the statistics, we should restart nginx worker
    # to cleanup unsynced stats.
    # TODO: It's hard to tell which nginx process belongs to us since it was
    # started by vcap_dev_setup, we may figure out an elegant way to do this
    # and get notification when it's ready instead of sleep 2 seconds.
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
    verify_results(results, app_socket, num_requests)


    # Verify bad cookie won't fail
    bad_cookie = "__VCAP_ID__=bad_cookie"
    sticky_request = simple_sticky_request('sticky.vcap.me', '/sticky', bad_cookie)

    results = send_requests_to_apps("127.0.0.1", RouterServer.port,
                                    sticky_request, num_requests, app_sockets,
                                    FOO_HTTP_RESPONSE)
    verify_results_by_request(results, num_requests)

    # Verify cookie to backend that never exists
    Router.config({})
    droplet = { :url => 'sticky.vcap.me', :host => '10.10.10.10', :port => 10 }
    down_dea_cookie = "__VCAP_ID__=#{Router.generate_session_cookie(droplet)}"
    sticky_request = simple_sticky_request('sticky.vcap.me', '/sticky', bad_cookie)

    results = send_requests_to_apps("127.0.0.1", RouterServer.port,
                                    sticky_request, num_requests, app_sockets,
                                    FOO_HTTP_RESPONSE)

    verify_results_by_request(results, num_requests)

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

    resp = app.get_trace_header("127.0.0.1", RouterServer.port, TRACE_KEY)

    resp.headers["X-Vcap-Backend"].should_not be_nil
    h, p = resp.headers["X-Vcap-Backend"].split(":")
    p.to_i.should == app.port.to_i

    resp.headers["X-Vcap-Router"].should_not be_nil
    resp.headers["X-Vcap-Router"].should == RouterServer.host

    dea.unregister_app(app)

    app.stop
  end

  it 'should not add vcap trace headers when trace key is wrong' do
    app = TestApp.new('trace.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app, {"component" => "trace", "runtime" => "ruby"})

    resp = app.get_trace_header("127.0.0.1", RouterServer.port, "fake_trace_key")

    resp.headers["X-Vcap-Backend"].should be_nil
    resp.headers["X-Vcap-Router"].should be_nil

    dea.unregister_app(app)

    app.stop
  end


end
