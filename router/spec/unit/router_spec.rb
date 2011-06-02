# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../spec_helper'

require 'router/router'
require 'logger'

require 'vcap/rolling_metric'

module VCAP
  class Component
    class << self
      attr_reader :varz
      def setup
        @varz = {}
      end
    end
  end
end

describe Router do

  before :all do
    Router.config({})
    VCAP::Component.setup
    VCAP::Component.varz[:urls] = 0
    VCAP::Component.varz[:droplets] = 0
    VCAP::Component.varz[:tags] = {}
  end

  describe 'Router.config' do
    it 'should set up a logger' do
      Router.log.should be_an_instance_of(Logging::Logger)
    end

    it 'should set up a session key' do
      Router.session_key.should be
    end

  end

  describe 'Router.register_droplet' do

    it 'should register a droplet' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      VCAP::Component.varz[:droplets].should == 1
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should allow proper lookup' do
      droplets = Router.lookup_droplet('foo.vcap.me')
      droplets.should be_instance_of Array
      droplets.should have(1).items

      droplet = droplets.first
      droplet.should have_key :url
      droplet.should have_key :timestamp
      droplet.should have_key :requests
      droplet.should have_key :host
      droplet.should have_key :port
      droplet.should have_key :clients
      droplet[:connections].should == []
      droplet[:requests].should == 0
      droplet[:url].should == 'foo.vcap.me'
      droplet[:host].should == '10.0.1.22'
      droplet[:port].should == 2222
      droplet[:clients].should == {}
    end

    it 'should count droplets independent of URL' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2224, {})
      VCAP::Component.varz[:droplets].should == 2
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should return multiple droplets for a url when they exist' do
      droplets = Router.lookup_droplet('foo.vcap.me')
      droplets.should be_instance_of Array
      droplets.should have(2).items
    end

    it 'should ignore duplicates' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2224, {})
      VCAP::Component.varz[:droplets].should == 2
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should record tags' do
      VCAP::Component.varz[:tags]["component"].should be_nil
      Router.register_droplet('foobar.vcap.me', '10.0.1.22', 2225, {"component" => "test"})
      VCAP::Component.varz[:tags]["component"]["test"].should_not be_nil
      droplets = Router.lookup_droplet('foobar.vcap.me')
      droplets.first[:tags].should == {"component" => "test"}
    end

  end

  describe 'Router.unregister_droplet' do
    it 'should unregister a droplet' do
      Router.unregister_droplet('foo.vcap.me', '10.0.1.22', 2224)
      VCAP::Component.varz[:droplets].should == 2
      VCAP::Component.varz[:urls].should == 2
    end

    it 'should unregister a droplet that had tags' do
      Router.unregister_droplet('foobar.vcap.me', '10.0.1.22', 2225)
      VCAP::Component.varz[:droplets].should == 1
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should not return unregistered items' do
      Router.unregister_droplet('foo.vcap.me', '10.0.1.22', 2222)
      droplets = Router.lookup_droplet('foo.vcap.me')
      droplets.should be_nil
    end

    it 'should properly account for urls and droplets' do
      VCAP::Component.varz[:droplets].should == 0
      VCAP::Component.varz[:urls].should == 0
    end
  end

  describe 'Router.session_keys' do
    it 'should properly encrypt and decrypt session keys' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      droplets = Router.lookup_droplet('foo.vcap.me')
      droplets.should have(1).items
      droplet = droplets.first
      key = Router.generate_session_cookie(droplet)
      key.should be
      droplet_array = Router.decrypt_session_cookie(key)
      droplet_array.should be_instance_of Array
      droplet_array.should have(3).items
      droplet_array[0].should == droplet[:url]
      droplet_array[1].should == droplet[:host]
      droplet_array[2].should == droplet[:port]
    end
end

end
