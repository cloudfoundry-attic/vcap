# Copyright (c) 2009-2011 VMware, Inc.
require "spec_helper"
require "vcap/spec/em"
require "em-http/version"

describe VCAP::Component do
  include VCAP::Spec::EM

  let(:nats) { NATS.connect(:uri => "nats://localhost:4223", :autostart => true) }
  let(:default_options) { { :type => "type", :nats => nats } }

  after :all do
    if File.exists? NATS::AUTOSTART_PID_FILE
      pid = File.read(NATS::AUTOSTART_PID_FILE).chomp.to_i
      `kill -9 #{pid}`
      FileUtils.rm_f NATS::AUTOSTART_PID_FILE
    end
  end

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

  it "should allow you to set an index" do
    em do
      options = default_options
      options[:index] = 5

      VCAP::Component.register(options)

      nats.request("vcap.component.discover") do |msg|
        body = Yajl::Parser.parse(msg, :symbolize_keys => true)
        body[:type].should == "type"
        body[:index].should == 5
        body[:uuid].should =~ /^5-.*/
        done
      end
    end
  end

  describe 'suppression of keys in config information in varz' do
    it 'should suppress certain keys in the top level config' do
      em do
        options = { :type => 'suppress_test', :nats => nats }
        options[:config] = {
          :mbus => 'nats://user:pass@localhost:4223',
          :keys => 'sekret!keys',
          :mysql => { :user => 'derek', :password => 'sekret!' },
          :password => 'crazy',
          :database_environment => { :stuff => 'should not see' }
        }
        VCAP::Component.register(options)
        done
      end
      VCAP::Component.varz.should include(:config => {})
    end

    it 'should suppress certain keys at any level in config' do
      em do
        options = { :type => 'suppress_test', :nats => nats }
        options[:config] = {
          :mbus => 'nats://user:pass@localhost:4223',
          :keys => 'sekret!keys',
          :mysql => { :user => 'derek', :password => 'sekret!' },
          :password => 'crazy',
          :database_environment => { :stuff => 'should not see' },
          :this_is_ok => { :password => 'sekret!', :mysql => 'sekret!', :test => 'ok'}
        }
        VCAP::Component.register(options)
        done
      end
      VCAP::Component.varz.should include(:config => { :this_is_ok => { :test => 'ok'}} )
    end

    it 'should leave config its passed untouched' do
      em do
        options = { :type => 'suppress_test', :nats => nats }
        options[:config] = {
          :mbus => 'nats://user:pass@localhost:4223',
          :keys => 'sekret!keys',
          :mysql => { :user => 'derek', :password => 'sekret!' },
          :password => 'crazy',
          :database_environment => { :stuff => 'should not see' },
          :this_is_ok => { :password => 'sekret!', :mysql => 'sekret!', :test => 'ok'}
        }
        VCAP::Component.register(options)

        options.should include(:config => {
          :mbus => 'nats://user:pass@localhost:4223',
          :keys => 'sekret!keys',
          :mysql => { :user => 'derek', :password => 'sekret!' },
          :password => 'crazy',
          :database_environment => { :stuff => 'should not see' },
          :this_is_ok => { :password => 'sekret!', :mysql => 'sekret!', :test => 'ok'}
        })
        done
      end
    end
  end

  describe "http endpoint" do
    let(:host) { VCAP::Component.varz[:host] }
    let(:http) { ::EM::HttpRequest.new("http://#{host}/varz") }
    let(:http2) { ::EM::HttpRequest.new("http://#{host}/varz") }
    let(:authorization) { { :head => { "authorization" => VCAP::Component.varz[:credentials] } } }

    it "should let you specify the port" do
      em do
        options = default_options
        options[:port] = 18123

        VCAP::Component.register(options)

        http.opts.port.should == 18123

        request = http.get authorization.merge(:path => "/varz")
        request.callback do
          request.response_header.status.should == 200
          done
        end
      end
    end

    it "should not truncate varz on second request" do
      em do
        options = default_options

        VCAP::Component.register(options)

        request = http.get authorization.merge(:path => "/varz")
        request.callback do
          request.response_header.status.should == 200
          content_length = request.response_header['CONTENT_LENGTH'].to_i

          VCAP::Component.varz[:var] = 'var'

          request2 = http2.get authorization.merge(:path => "/varz")
          request2.callback do
            request2.response_header.status.should == 200
            content_length2 = request2.response_header['CONTENT_LENGTH'].to_i
            content_length2.should == request2.response.length
            content_length2.should > content_length
            done
          end
        end
      end
    end

    it "should not truncate healthz on second request" do
      em do
        options = default_options

        VCAP::Component.register(options)

        request = http.get authorization.merge(:path => "/healthz")
        request.callback do
          request.response_header.status.should == 200

          VCAP::Component.healthz = 'healthz'

          request2 = http2.get authorization.merge(:path => "/healthz")
          request2.callback do
            request2.response_header.status.should == 200
            content_length2 = request2.response_header['CONTENT_LENGTH'].to_i
            content_length2.should == request2.response.length
            content_length2.should == 'healthz'.length
            done
          end
        end
      end
    end

    it "should let you specify the auth" do
      em do
        options = default_options
        options[:user] = "foo"
        options[:password] = "bar"

        VCAP::Component.register(options)

        VCAP::Component.varz[:credentials].should == ["foo", "bar"]

        request = http.get authorization.merge(:path => "/varz")
        request.callback do
          request.response_header.status.should == 200
          done
        end
      end
    end

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
