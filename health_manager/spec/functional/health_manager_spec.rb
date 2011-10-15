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
  end

  after :all do
    # Cleanup after ourselves
    FileUtils.rm_rf(@test_dir)
  end

  before :each do
    # Create a directory per scenario to store log files, pid files, etc.
    @run_dir = File.join(@test_dir, "run_#{run_id_ctr}")
    create_dir(@run_dir)

    @helper = HMExpectedStateHelperDB.new( 'run_dir' => @run_dir)

    # NATS
    port = VCAP.grab_ephemeral_port
    pid_file = File.join(@run_dir, 'nats.pid')
    @nats_uri = "nats://localhost:#{port}"
    @nats_server = VCAP::Spec::ForkedComponent::NatsServer.new(pid_file, port, @run_dir)

    # HM
    @hm_cfg = {
      'mbus'         => @nats_uri,
      'local_route' => '127.0.0.1',
      'intervals'    => {

        'database_scan' => 2, #60
        'droplet_lost' => 4, #30
        'droplet_analysis' => 4, #10
        'flapping_death' => 4, #3
        'flapping_timeout' => 9, #180
        'restart_timeout' => 15, #20

        'stable_state' => 5, #60
        'nats_ping' => 1,
      },
      'logging'      => {'level' => 'debug'},
      'pid'          => File.join(@run_dir, 'health_manager.pid'),

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

    @app_state_file = File.join(@run_dir, 'db', 'applications.json')
  end

  after :each do
    run_id_ctr += 1
  end

  describe 'when running' do
    before :each do
      @helper.prepare_tests

      # @nats_server.reopen_stdio= false

      @nats_server.start
      @nats_server.wait_ready.should be_true

      start_msg = nil

      #receive_message is now refactored to take an optional block.
      #the block is what is expected to trigger the message that
      #we expect to receive.

      start_msg = receive_message 'healthmanager.start' do
        # @hm.reopen_stdio = false
        @hm.start
      end

      start_msg.should_not be_nil

    end

    after :each do
      @hm.stop
      @hm.running?.should be_false
      @nats_server.stop
      @nats_server.running?.should be_false
      @helper.release_resources
    end

    it 'should receive healthmanager.nats.ping message' do
      msg = receive_message 'healthmanager.nats.ping'
      msg.should_not be_nil
    end


    it 'should be able to new App entries' do
      app_name = 'test_app'
      @helper.add_app make_app_def app_name
      app = @helper.find_app :name => app_name
      app.should_not be_nil
      app[:name].should == app_name
    end

    it 'shoule be able to create User entries' do
      @helper.add_user make_user_def
      user = @helper.find_user :email => make_user_def[:email]

      user.should_not be_nil
      user[:email].should_not be_nil
      user[:email].should == make_user_def[:email]

    end

    it 'should send START message for a new instance' do
      app = nil
      msg = receive_message 'cloudcontrollers.hm.requests', 'app_create_prompter' do
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

    pending 'should signal STOP message for a stopped app' do
      app_def = make_app_def 'to_be_stopped'
      app_def['state'] = 'STOPPED'

      msg = receive_message 'cloudcontrollers.hm.requests', 'app_stop_prompter' do
        app = @helper.make_app_with_owner_and_instance(app_def,
                                                       make_user_def)

        heartbeat = {
          'droplets' =>
          [{
             'droplet' => app.id,
             'version' => 0,
             'instance' => 0,
             'index' => 0,
             'state' => 'STARTED',
             'state_timestamp' => 0
           }]
        }.to_json
        NATS.publish('dea.heartbeat',heartbeat)
      end

      msg.should_not be_nil
      puts msg
      msg = parse_json msg
      msg['op'].should == 'STOP'
      msg['droplet'].should == app.id

    end

  end

  def make_user_def
    { :email => 'boo@boo.com', :crypted_password => 'boo' }
  end

  def make_app_def app_name
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

  def send_request(uri, subj, req, timeout=10)
    response = nil
    em_run_with_timeout(timeout) do
      NATS.start(:uri => uri) do
        NATS.request(subj, req) do |msg|
          response = msg
          EM.stop
        end
      end
    end
    response
  end

  def parse_json str
    Yajl::Parser.parse(str)
  end


  def receive_message subj, prompting_msg='foo', timeout=15
    ret = nil
    em_run_with_timeout do
      NATS.start :uri => @nats_server.uri do
        NATS.subscribe(subj) do |msg|
          ret = msg
          EM.stop
        end
        if block_given?
          NATS.publish(prompting_msg) { yield }
        end
      end
    end
    ret
  end

  # NB: This is intended to be used without the event-loop already running.
  #     (We expect to block here.)
  def em_run_with_timeout(timeout=10)
    EM.run do
      EM.add_timer(timeout) {
        puts 'TIMEOUT!'
        EM.stop
      }
      yield
    end
  end
end
