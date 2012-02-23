# Copyright (c) 2009-2011 VMware, Inc.
require File.join(File.dirname(__FILE__), 'spec_helper')

require 'digest/sha1'
require 'fileutils'
require 'nats/client'
require 'uri'
require 'vcap/common'
require 'yaml'

describe 'Health Manager' do
  nats_timeout_path = File.expand_path(File.join(File.dirname(__FILE__), 'nats_timeout'))
  hm_path = File.expand_path(File.join(__FILE__, "../../../bin/health_manager"))
  run_id_ctr = 0

  before :all do
    # Base test directory to house invididual run directories
    @test_dir = "/tmp/hm_tests_#{Process.pid}_#{Time.now.to_i}"
    FileUtils.mkdir(@test_dir)
    File.directory?(@test_dir).should be_true
    @run_id = 0

    @run_dir = File.join(@test_dir, "run_#{run_id_ctr}")
    create_dir(@run_dir)

    @helper = HMExpectedStateHelperDB.new( 'run_dir' => @run_dir)

    # NATS
    port = VCAP.grab_ephemeral_port
    pid_file = File.join(@run_dir, 'nats.pid')
    @nats_uri = "nats://localhost:#{port}"
    @nats_server = VCAP::Spec::ForkedComponent::NatsServer.new(pid_file, port, @run_dir)

    @nats_server.start
    @nats_server.wait_ready.should be_true

    @hm_cfg = {
      'mbus'         => @nats_uri,
      'local_route' => '127.0.0.1',
      'intervals'    => {
        'database_scan' => 1, #60
        'droplet_lost' => 1, #30
        'droplets_analysis' => 1, #10
        'flapping_death' => 4, #3
        'flapping_timeout' => 9, #180
        'restart_timeout' => 15, #20
        'stable_state' => -1, #ensures all apps are "quiescent" for the purpose of testing
        'nats_ping' => 1,
      },
      'logging'      => {'level' => 'warn'},
      'pid'          => File.join(@run_dir, 'health_manager.pid'),
      'dequeueing_rate' => 0,
      'rails_environment' => 'test',
      'database_environment' =>{
        'test' => @helper.config
      }
    }
    @hm_config_file = File.join(@run_dir, 'health_manager.config')
    File.open(@hm_config_file, 'w') {|f| YAML.dump(@hm_cfg, f) }
    @hm = HealthManagerComponent.
      new("ruby -r#{nats_timeout_path} #{hm_path} -c #{@hm_config_file}",
          @hm_cfg['pid'],@hm_cfg, @run_dir)

    @helper.prepare_tests
    receive_message 'healthmanager.start' do
      @hm.start
    end.should_not be_nil
  end

  after :all do
    # Cleanup after ourselves
    @nats_server.stop
    @nats_server.running?.should be_false

    @hm.stop
    @hm.running?.should be_false
    @helper.release_resources

    FileUtils.rm_rf(@test_dir)
  end

  describe 'when running' do
    before :each do
      @helper.delete_all
    end

    #TODO: test stop duplicate instances
    #TODO: test heartbeat timeout
    #TODO: test respond to health requests
    #TODO: test flapping instances
    #TODO: test wait for droplet to be stable
    #TODO: test that droplets have a chance to restart

    #test start missing instances
    it 'should start missing instances' do
      app = nil
      msg = receive_message 'cloudcontrollers.hm.requests' do
        #putting enough into Expected State to trigger an instance START request
        app = @helper.make_app_with_owner_and_instance(
                                                       make_app_def( 'to_be_started_app'),
                                                       make_user_def)
      end
      app.should_not be_nil
      msg.should_not be_nil
      msg = parse_json msg
      msg['op'].should == 'START'
      msg['droplet'].should == app.id
    end

    #test restart crashed instances
    it 'should start crashed instances' do
      app = @helper.make_app_with_owner_and_instance(make_app_def('crasher'), make_user_def)
      crash_msg = {
        'droplet' =>  app.id,
        'version' => 0,
        'instance' => 0,
        'index' => 0,
        'reason' => 'CRASHED',
        'crash_timestamp' => Time.now.to_i
      }
      msg = receive_message 'cloudcontrollers.hm.requests' do
        NATS.publish('droplet.exited', crash_msg.to_json)
      end
      msg.should_not be_nil
      msg = parse_json(msg)
      msg['droplet'].should == app.id
      msg['op'].should == 'START'
      msg['version'].to_i.should == crash_msg['version']
    end
  end

  def make_user_def
    { :email => 'boo@boo.com', :crypted_password => 'boo' }
  end

  def make_app_def(app_name)
    {
      :name => app_name,
      :framework => 'sinatra',
      :runtime => 'ruby19',
      :state => 'STARTED',
      :package_state => 'STAGED'
    }
  end

  def create_dir(dir)
    File.directory?(dir).should be_false
    FileUtils.mkdir(dir)
    File.directory?(dir).should be_true
  end

  def parse_json(str)
    Yajl::Parser.parse(str)
  end

  def receive_message(subj)
    ret = nil
    timeout = 10
    EM.run do
      EM.add_timer(timeout) do
        puts "TIMEOUT while waiting on #{subj}"
        EM.stop
      end
      NATS.start :uri => @nats_server.uri do
        NATS.subscribe(subj) do |msg|
          ret = msg
          EM.stop
        end
        if block_given?
          NATS.publish('foo') { yield }
        end
      end
    end
    ret
  end
end
