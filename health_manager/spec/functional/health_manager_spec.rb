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

    # NATS
    port = VCAP.grab_ephemeral_port
    pid_file = File.join(@run_dir, 'nats.pid')
    @nats_uri = "nats://localhost:#{port}"
    @nats_server = VCAP::Spec::ForkedComponent::NatsServer.new(pid_file, port, @run_dir)


    #DB config
    @db_config = {
      'adapter' => 'sqlite3',
      'database' =>  File.join(@run_dir, 'test.sqlite3'),
      'encoding' => 'utf8'
    }

    # HM
    @hm_cfg = {
      'base_dir'     => @run_dir,
      'filer_port'   => VCAP.grab_ephemeral_port,
      'mbus'         => @nats_uri,
      'intervals'    => {'heartbeat' => 1},
      'logging'      => {'level' => 'debug'},

      'pid'          => File.join(@run_dir, 'health_manager.pid'),

      'rails_environment' => 'test',
      'database_environment' =>{
        'test' => @db_config
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
      @nats_server.start
      @nats_server.wait_ready.should be_true



      start_msg = nil
      em_run_with_timeout do
        NATS.start(:uri => @nats_server.uri) do
          NATS.subscribe('healthmanager.start') do |msg|
            start_msg = msg
            EM.stop
          end
          # This is a little weird, but it ensures that our subscribe has been processed
          NATS.publish('foo') { @hm.start }
        end
      end

      connect_and_prep_test_db
      start_msg.should_not be_nil
    end

    after :each do

      disconnect_from_db

      @hm.stop
      @hm.running?.should be_false

      @nats_server.stop
      @nats_server.running?.should be_false
    end

    it 'should receive healthmanager.nats.ping message' do
      msg = receive_message('healthmanager.nats.ping')
      msg.should_not be_nil
    end

    it 'should be able to access App model' do
      App
    end

##  it 'should be able to new App entries' do
##    app_name = 'test_app'
##
##    app = App.new(
##                  {
##                    'name' => app_name,
##
##                  }
##
##                  )
##
##    app.save
##    app = App.find_by_name(test_app)
##    app.should_not be_nil
##    app.name.should_not be_nil
##    app.name.should = test_app
##
##  end



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

  def receive_message subj, timeout=15
    ret = nil
    em_run_with_timeout do
      NATS.start :uri => @nats_server.uri do
        NATS.subscribe(subj) do |msg|
          ret = msg
          EM.stop
        end
      end
    end
    ret
  end

  # NB: This is intended to be used without the event-loop already running.
  #     (We expect to block here.)
  def em_run_with_timeout(timeout=10)
    EM.run do
      EM.add_timer(timeout) { EM.stop }
      yield
    end
  end
end

def connect_and_prep_test_db
  ActiveRecord::Base.establish_connection(@db_config)
  #schema initialization and populating data will go here

end

def disconnect_from_db
  #database clean-up goes here
  ActiveRecord::Base.clear_all_connections!
end
