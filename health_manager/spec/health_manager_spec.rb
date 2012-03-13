# Copyright (c) 2009-2011 VMware, Inc.
require 'spec_helper'

#functional tests are now implemented in functional/health_manager_spec.rb

describe HealthManager do

  def build_user
    @user = ::User.find_by_email('test@example.com')
    unless @user
      @user = ::User.new(:email => "test@example.com")
      @user.set_and_encrypt_password('HASHEDPASSWORD')
      @user.save!
    end
    @user
  end

  def make_db_app_entry(appname)
    app = @user.apps.find_by_name(appname)
    unless app
      app = ::App.new(:name => appname, :owner => @user, :runtime => "ruby19", :framework => "sinatra")
      app.package_hash = random_hash
      app.staged_package_hash = random_hash
      app.state = "STARTED"
      app.package_state = "STAGED"
      app.instances = 3
      app.save!
    end
    app
  end

  def build_app(appname = 'testapp')
    @app = make_db_app_entry(appname)
    @app.set_urls(["http://#{appname}.vcap.me"])

    @droplet_entry = {
        :last_updated => @app.last_updated - 2, # take off 2 seconds so it looks 'quiescent'
        :state => 'STARTED',
        :crashes => {},
        :versions => {},
        :live_version => "#{@app.staged_package_hash}-#{@app.run_count}",
        :instances => @app.instances,
        :framework => 'sinatra',
        :runtime => 'ruby19'
    }
    @hm.update_droplet(@app)
    @app
  end

  def random_hash(len=40)
    res = ""
    len.times { res << rand(16).to_s(16) }
    res
  end

  def build_user_and_app
    build_user
    build_app
  end

  def should_publish_to_nats(message, payload)
    NATS.should_receive(:publish).with(message, payload.to_json)
  end

  after(:each) do
    VCAP::Logging.reset
  end

  after(:all) do
    ::User.destroy_all
    ::App.destroy_all
  end

  before(:each) do
    @hm = HealthManager.new({
      'mbus' => 'nats://localhost:4222/',
      'logging' => {
        'level' => ENV['LOG_LEVEL'] || 'warn',
      },
      'intervals' => {
        'database_scan' => 1,
        'droplet_lost' => 300,
        'droplets_analysis' => 0.5,
        'flapping_death' => 3,
        'flapping_timeout' => 5,
        'restart_timeout' => 2,
        'stable_state' => -1,

                              },
        'dequeueing_rate' => 50,
      'rails_environment' => 'test',
      'database_environment' => {
        'test' => {
          'adapter' => 'sqlite3',
          'database' => 'db/test.sqlite3',
          'encoding' => 'utf8'
        }
      }
    })
    hash = Hash.new {|h,k| h[k] = 0}
    VCAP::Component.stub!(:varz).and_return(hash)
    ::User.destroy_all
    ::App.destroy_all

    build_user_and_app
  end

  def make_heartbeat_message(indices, state)
    droplets = []
    indices.each do |index|
      droplets << {
          'droplet' => @app.id, 'index' => index, 'instance' => index, 'state' => state,
          'version' => @droplet_entry[:live_version], 'state_timestamp' => @droplet_entry[:last_updated]
      }
    end
    { 'droplets' => droplets }.to_json
  end

  describe '#perform_quantum' do
    it 'should be resilient to nil arguments' do
      @hm.perform_quantum(nil, nil)
    end
  end


  it "should detect instances that are down and send a START request" do
    stats = { :frameworks => {}, :runtimes => {}, :down => 0 }
    should_publish_to_nats "cloudcontrollers.hm.requests", {
          'droplet' => @app.id,
          'op' => 'START',
          'last_updated' => @app.last_updated.to_i,
          'version' => "#{@app.staged_package_hash}-#{@app.run_count}",
          'indices' => [0,1,2]
        }

    @hm.analyze_app(@app.id, @droplet_entry, stats)
    @hm.deque_a_batch_of_requests

    stats[:down].should == 3
    stats[:frameworks]['sinatra'][:missing_instances].should == 3
    stats[:runtimes]['ruby19'][:missing_instances].should == 3
  end

  it "should detect extra instances and send a STOP request" do
    stats = { :frameworks => {}, :runtimes => {}, :running => 0, :down => 0 }
    timestamp = Time.now.to_i
    version_entry = { indices: {
        0 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '0' },
        1 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '1' },
        2 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '2' },
        3 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '3' }
    }}
    should_publish_to_nats "cloudcontrollers.hm.requests", {
          'droplet' => @app.id,
          'op' => 'STOP',
          'last_updated' => @app.last_updated.to_i,
          'instances' => [ version_entry[:indices][3][:instance] ]
        }
    @droplet_entry[:versions][@droplet_entry[:live_version]] = version_entry

    @hm.analyze_app(@app.id, @droplet_entry, stats)

    stats[:running].should == 3
    stats[:frameworks]['sinatra'][:running_instances].should == 3
    stats[:runtimes]['ruby19'][:running_instances].should == 3
  end

  it "should update its internal state to reflect heartbeat messages" do
    droplet_entries = @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING"))

    droplet_entries.size.should == 1
    droplet_entry = droplet_entries[0]
    droplet_entry[:versions].should_not be_nil
    version_entry = droplet_entry[:versions][@droplet_entry[:live_version]]
    version_entry.should_not be_nil
    index_entry = version_entry[:indices][0]
    index_entry.should_not be_nil
    index_entry[:state].should == 'RUNNING'
  end

  it "should restart an instance that exits unexpectedly" do
    should_publish_to_nats "cloudcontrollers.hm.requests", {
          'droplet' => @app.id,
          'op' => 'START',
          'last_updated' => @app.last_updated.to_i,
          'version' => "#{@app.staged_package_hash}-#{@app.run_count}",
          'indices' => [0]
        }

    @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING"))
    droplet_entry = @hm.process_exited_message({
                                                     'droplet' => @app.id,
                                                     'version' => "#{@app.staged_package_hash}-#{@app.run_count}",
                                                     'index' => 0,
                                                     'instance' => 0,
                                                     'reason' => 'CRASHED',
                                                     'crash_timestamp' => Time.now.to_i
                                               }.to_json)
    @hm.deque_a_batch_of_requests

    droplet_entry[:versions].should_not be_nil
    version_entry = droplet_entry[:versions][@droplet_entry[:live_version]]
    version_entry.should_not be_nil
    index_entry = version_entry[:indices][0]
    index_entry.should_not be_nil
    index_entry[:state].should == 'DOWN'
  end

  it "should not re-start timer-triggered analysis loop if previous analysis loop is still in progress" do

    n=20
    apps = []

    n.times { |i|
      apps << make_db_app_entry("test#{i}")
    }

    VCAP::Component.varz[:running] = {}
    @hm.update_from_db

    EM.run do

      @hm.analysis_in_progress?.should be_false

      @hm.analyze_all_apps.should be_true

      @hm.analysis_in_progress?.should be_true

      @hm.analyze_all_apps.should be_false

      EM.add_timer(2) {
        EM.stop
      }
    end

  end


  it "should have FIFO behavior for DEA_EVACUATION-triggered restarts" do

    apps = []

    apps << @app
    apps << build_app('test2')
    apps << build_app('test3')

    apps.each do |app|

      should_publish_to_nats("cloudcontrollers.hm.requests", {
                               'droplet' => app.id ,
                               'op' => 'START',
                               'last_updated' => app.last_updated.to_i,
                               'version' => "#{app.staged_package_hash}-#{app.run_count}",
                               'indices' => [0]

                             }).ordered #CRUCIAL
    end


    apps.each do |app|
      @hm.process_exited_message({
                                   'droplet' => app.id,
                                   'version' => "#{app.staged_package_hash}-#{app.run_count}",
                                   'index' => 0,
                                   'instance' => 0,
                                   'reason' => 'DEA_EVACUATION',
                                   'crash_timestamp' => Time.now.to_i
                                 }.to_json)
    end
    @hm.deque_a_batch_of_requests
  end
end
