# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/spec_helper'
require "base64"

describe 'Router Functional Tests' do

  include Functional

  ROUTER_V1_DROPLET = { :url => 'router_test.vcap.me', :host => '127.0.0.1', :port => 12345 }
  ROUTER_V1_SESSION = "zXiJv9VIyWW7kqrcqYUkzj+UEkC4UUHGaYX9fCpDMm2szLfOpt+aeRZMK7kfkpET+PDhvfKRP/M="

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
    varz[:type].should =~ /router/i
  end

  it 'should properly register an application endpoint' do
    # setup the "app"
    app = TestApp.new('router_test.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app)
    app.verify_registered
  end

  it 'should properly unregister an application endpoint' do
    # setup the "app"
    app = TestApp.new('router_test.vcap.me')
    dea = DummyDea.new(@nats_server.uri, '1234')
    dea.register_app(app)
    app.verify_registered
    dea.unregister_app(app)
    app.verify_unregistered
  end

  it 'should generate the same token as router v1 did' do
    Router.config({})
    token = Router.generate_session_cookie(ROUTER_V1_DROPLET)
    token.should == ROUTER_V1_SESSION
  end

  it 'should decrypt router v1 session' do
    Router.config({})
    url, host, port = Router.decrypt_session_cookie(ROUTER_V1_SESSION)
    url.should  == ROUTER_V1_DROPLET[:url]
    host.should == ROUTER_V1_DROPLET[:host]
    port.should == ROUTER_V1_DROPLET[:port]
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

end
