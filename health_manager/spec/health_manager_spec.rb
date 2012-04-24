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

    @config = {
      'mbus' => 'nats://localhost:4222/',
      'logging' => {
        'level' => ENV['LOG_LEVEL'] || 'warn',
      },
      'intervals' => {
        'database_scan' => 1,
        'droplet_lost' => 300,
        'droplets_analysis' => 0.5,
        'flapping_death' => @flapping_death = 2,
        'min_restart_delay' => @min_restart_delay = 1,
        'max_restart_delay' => @max_restart_delay = 3,
        'giveup_crash_number' => @giveup_crash_number = 5,
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
    }

    @hm = HealthManager.new(@config)

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
    { 'droplets' => droplets }
  end

  def make_crashed_message
    {
      'droplet' => @app.id,
      'version' => "#{@app.staged_package_hash}-#{@app.run_count}",
      'index' => 0,
      'instance' => 0,
      'reason' => 'CRASHED',
      'crash_timestamp' => Time.now.to_i
    }
  end

  def make_restart_message(options = {})
    m = {
      'droplet' => @app.id,
      'op' => 'START',
      'last_updated' => @app.last_updated.to_i,
      'version' => "#{@app.staged_package_hash}-#{@app.run_count}",
      'indices' => [0]
    }.merge(options)
  end

  def get_live_index(droplet_entry,index)
    droplet_entry[:versions].should_not be_nil
    version_entry = droplet_entry[:versions][@droplet_entry[:live_version]]
    version_entry.should_not be_nil
    version_entry[:indices][index].should_not be_nil
    version_entry[:indices][index]
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
    droplet_entries = @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING").to_json)

    droplet_entries.size.should == 1
    droplet_entry = droplet_entries[0]
    get_live_index(droplet_entry,0)[:state].should == 'RUNNING'
  end

  it "should restart an instance that exits unexpectedly" do
    ensure_non_flapping_restart
  end

  it "should exponentially delay restarts for flapping instance" do
    @flapping_death.times {
      ensure_non_flapping_restart
    }

    delay = @min_restart_delay

    (@giveup_crash_number - @flapping_death).times {
      ensure_flapping_delayed_restart(delay)
      delay *= 2
      delay = @max_restart_delay if delay > @max_restart_delay
    }
    ensure_gaveup_restarting
  end

  def ensure_non_flapping_restart
    should_publish_to_nats "cloudcontrollers.hm.requests", make_restart_message
    @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING").to_json)
    droplet_entry = @hm.process_exited_message(make_crashed_message.to_json)
    @hm.deque_a_batch_of_requests
    get_live_index(droplet_entry,0)[:state].should == 'DOWN'
    @hm.restart_pending?(@app.id, 0).should be_false # first @flapping_death restarts are immediate.
  end

  def ensure_flapping_delayed_restart(delay)
    in_em_with_fiber do |f|

      should_publish_to_nats "cloudcontrollers.hm.requests", make_restart_message('flapping' => true)

      @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING").to_json)
      droplet_entry = @hm.process_exited_message(make_crashed_message.to_json)

      get_live_index(droplet_entry,0)[:state].should == 'FLAPPING'
      @hm.restart_pending?(@app.id, 0).should be_true


      # half a second before the delay elapses the restart is still pending
      EM.add_timer(delay - 0.5) do
        @hm.restart_pending?(@app.id, 0).should be_true
        @hm.deque_a_batch_of_requests
        @hm.restart_pending?(@app.id, 0).should be_true
      end

      # after delay elapses, the pending restart is initiated and is no longer pending
      EM.add_timer(delay + 0.5) do
        @hm.restart_pending?(@app.id, 0).should be_true
        @hm.deque_a_batch_of_requests
        @hm.restart_pending?(@app.id, 0).should be_false
        f.resume
      end
    end
  end

  def ensure_gaveup_restarting
    @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING").to_json)
    droplet_entry = @hm.process_exited_message(make_crashed_message.to_json)
    get_live_index(droplet_entry,0)[:state].should == 'FLAPPING'
    get_live_index(droplet_entry,0)[:crashes].should > @giveup_crash_number
    @hm.restart_pending?(@app.id, 0).should be_false
  end

  def in_em_with_fiber
    in_em do
      Fiber.new {
        yield Fiber.current
        Fiber.yield
        EM.stop
      }.resume
    end
  end

  def in_em(timeout = 10)
    EM.run do
      EM.add_timer(timeout) do
        EM.stop
        fail "Failed to complete withing allotted timeout"
      end
      yield
    end
  end

  it "should not re-start timer-triggered analysis loop if previous analysis loop is still in progress" do

    n=20
    apps = []

    n.times { |i|
      apps << make_db_app_entry("test#{i}")
    }

    VCAP::Component.varz[:running] = {}
    @hm.update_from_db

    in_em do
      @hm.analysis_in_progress?.should be_false
      @hm.analyze_all_apps.should be_true
      @hm.analysis_in_progress?.should be_true
      @hm.analyze_all_apps.should be_false
      EM.stop
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
