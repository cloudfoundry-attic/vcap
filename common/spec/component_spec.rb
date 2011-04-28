# Copyright (c) 2009-2011 VMware, Inc.
require "spec_helper"
require "vcap/spec/em"
require "em-http/version"

describe VCAP::Component do
  include VCAP::Spec::EM

  let(:nats) { NATS.connect(:uri => "mbus://127.0.0.1:4223", :autostart => true) }
  let(:default_options) { { :type => "type", :nats => nats } }

  it "should publish an announcement" do
    em(:timeout => 1) do
      nats.subscribe("vcap.component.announce") do |msg|
        body = Yajl::Parser.parse(msg, :symbolize_keys => true)
        body[:type].should == "type"
        done
      end

      VCAP::Component.register(default_options)
    end
  end

  it "should listen for discovery messages" do
    em do
      VCAP::Component.register(default_options)

      nats.request("vcap.component.discover") do |msg|
        body = Yajl::Parser.parse(msg, :symbolize_keys => true)
        body[:type].should == "type"
        done
      end
    end
  end

  describe "http endpoint" do
    let(:host) { VCAP::Component.varz[:host] }
    let(:http) { ::EM::HttpRequest.new("http://#{host}/varz") }
    let(:authorization) { { :head => { "authorization" => VCAP::Component.varz[:credentials] } } }

    it "should skip keep-alive by default" do
      em do
        VCAP::Component.register(default_options)

        request = http.get authorization
        request.callback do
          request.response_header.should_not be_keepalive

          request = http.get authorization
          request.callback { raise "second request shouldn't succeed" }
          request.errback { done }
        end
      end
    end

    it "should support keep-alive" do
      em do
        VCAP::Component.register(default_options)

        first_peername = nil
        request = http.get authorization.merge(:path => "/varz", :keepalive => true)
        request.callback do
          request.response_header.should be_keepalive
          first_peername = http.get_peername
          first_peername.should be

          request = http.get authorization.merge(:path => "/varz", :keepalive => true)
          request.callback do
            request.response_header.should be_keepalive
            second_peername = http.get_peername
            second_peername.should eql first_peername
            done
          end
        end
      end
    end

    it "should return 401 on unauthorized requests" do
      em do
        VCAP::Component.register(default_options)

        request = http.get :path => "/varz"
        request.callback do
          request.response_header.status.should == 401
          done
        end
      end
    end

    it "should return 400 on malformed authorization header" do
      em do
        VCAP::Component.register(default_options)

        request = http.get :path => "/varz", :head => { "authorization" => "foo" }
        request.callback do
          request.response_header.status.should == 400
          done
        end
      end
    end
  end
end
