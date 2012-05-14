# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../spec_helper'

require 'router/router'
require 'logger'

require 'vcap/logging'
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
  describe 'Router.config' do
    before :each do
      clear_router
    end
  end

  describe 'Router.register_droplet' do
    before :each do
      clear_router
    end

    it 'should register a droplet' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      VCAP::Component.varz[:droplets].should == 1
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should allow proper lookup' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
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
      droplet[:requests].should == 0
      droplet[:url].should == 'foo.vcap.me'
      droplet[:host].should == '10.0.1.22'
      droplet[:port].should == 2222
      droplet[:clients].should == {}
    end

    it 'should allow looking up uppercase uri' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      droplets = Router.lookup_droplet('FOO.VCAP.ME')
      droplets.should be_instance_of Array
      droplets.should have(1).items
    end

    it 'should count droplets independent of URL' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2224, {})
      VCAP::Component.varz[:droplets].should == 2
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should return multiple droplets for a url when they exist' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2224, {})
      droplets = Router.lookup_droplet('foo.vcap.me')
      droplets.should be_instance_of Array
      droplets.should have(2).items
    end

    it 'should ignore duplicates' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2224, {})
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
    before :each do
      clear_router
    end

    it 'should unregister a droplet' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2224, {})
      Router.unregister_droplet('foo.vcap.me', '10.0.1.22', 2224)
      VCAP::Component.varz[:droplets].should == 1
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should unregister a droplet that had tags' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2224, {})
      Router.register_droplet('foobar.vcap.me', '10.0.1.22', 2225, {"component" => "test"})
      Router.unregister_droplet('foobar.vcap.me', '10.0.1.22', 2225)
      VCAP::Component.varz[:droplets].should == 1
      VCAP::Component.varz[:urls].should == 1
    end

    it 'should not return unregistered items' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      Router.unregister_droplet('foo.vcap.me', '10.0.1.22', 2222)
      droplets = Router.lookup_droplet('foo.vcap.me')
      droplets.should be_nil
    end

    it 'should properly account for urls and droplets' do
      Router.register_droplet('foo.vcap.me', '10.0.1.22', 2222, {})
      Router.unregister_droplet('foo.vcap.me', '10.0.1.22', 2222)
      VCAP::Component.varz[:droplets].should == 0
      VCAP::Component.varz[:urls].should == 0
    end
  end

  def clear_router
    Router.config({})
    Router.instance_variable_set(:@log, double(:black_hole).as_null_object)
    VCAP::Component.setup
    VCAP::Component.varz[:urls] = 0
    VCAP::Component.varz[:droplets] = 0
    VCAP::Component.varz[:tags] = {}
  end
end
