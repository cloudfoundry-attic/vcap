# Copyright (c) 2009-2011 VMware, Inc.
require 'spec_helper'
require 'benchmark'

#functional tests are now implemented in functional/health_manager_spec.rb
class HealthManager
  def get_droplet id
    @droplets[id]
  end
  def get_droplets
    @droplets
  end
  def get_flapping_versions
    @flapping_versions
  end
  def set_flapping_versions value
    @flapping_versions = value
  end
end

describe HealthManager do

  def build_user(prefix='test')
    email = prefix + '@example.com'
    user = ::User.find_by_email(email)
    unless user
      user = ::User.new(:email => email)
      user.set_and_encrypt_password('HASHEDPASSWORD')
      user.save!
    end
    user
  end

  def build_app(user, prefix='test')
    appname = prefix+'app'
    app = user.apps.find_by_name(appname)
    unless app
      app = ::App.new(:name => appname, :owner => user, :runtime => "ruby19", :framework => "sinatra")
      app.package_hash = Digest::MD5.hexdigest("package_hash"+appname)
      app.staged_package_hash = Digest::MD5.hexdigest("staged_package_hash"+appname)
      app.state = "STARTED"
      app.package_state = "STAGED"
      app.instances = 3
      app.save!
      app.set_urls(['http://'+appname+'.vcap.me'])
    end
    app
  end

  def build_user_and_app(prefix = 'test')
    user = build_user(prefix)
    @app = build_app(user, prefix)

    @droplet_entry = {
        :last_updated => @app.last_updated - 2,
        :state => 'STARTED',
        :crashes => {},
        :versions => {},
        :live_version => "#{@app.staged_package_hash}-#{@app.run_count}",
        :instances => @app.instances,
        :framework => 'sinatra',
        :runtime => 'ruby19'
    }
    @hm.update_droplet(@app)

  end

  def build_many_users_and_apps(n_users, n_apps_per)

    n_users.times do |i|
      user = build_user('test'+i.to_s)
      n_apps_per.times do |j|
        prefix = "test#{i}-#{j}"
        app = build_app(user, prefix)
        @hm.update_droplet(app)
      end
    end
  end


  def should_publish_to_nats(message, payload)
    NATS.should_receive(:publish).with(message, payload.to_json)
  end

  after(:all) do
    clean_db
  end

  def clean_db
    ::User.destroy_all
    ::App.destroy_all
  end

  before(:all) do
    @flapping_death = 3
  end

  before(:each) do
    create_hm
    hash = Hash.new {|h,k| h[k] = 0}
    hash[:running] = Hash.new {|h,k| h[k] = 0}
    VCAP::Component.stub!(:varz).and_return(hash)
    build_user_and_app
  end

  after(:each) do
    FileUtils.rm_rf('/tmp/flapping_versions')
  end


  def create_hm options = {}
    VCAP::Logging.reset
    @hm = HealthManager.new({
      'mbus' => 'nats://localhost:4222/',
      'logging' => {
        'level' => 'warn',
      },
      'intervals' => {
        'database_scan' => 1,
        'droplet_lost' => 300,
        'droplets_analysis' => 0.5,
        'flapping_death' => @flapping_death,
        'flapping_timeout' => 5,
        'restart_timeout' => 2,
        'stable_state' => -1, #ensures all droplets are deemed quiescent for testing pursposes
        'request_queue' => 0
      },
      'rails_environment' => 'test',
      'database_environment' => {
        'test' => {
          'adapter' => 'sqlite3',
          'database' => 'db/test.sqlite3',
          'encoding' => 'utf8'
        }
      }
    }.merge options)
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

  def should_publish_start_message(options = {})

    message = {
      'droplet' => @app.id,
      'op' => 'START',
      'last_updated' => @app.last_updated.to_i,
      'version' => "#{@app.staged_package_hash}-#{@app.run_count}",
      'indices' => [0]
    }.merge options

    should_publish_to_nats("cloudcontrollers.hm.requests", message)
  end

  it "should detect instances that are down and send a START request" do

    should_publish_start_message('indices' => [0,1,2])

    stats = analyze_app


    stats[:down].should == 3
    stats[:frameworks]['sinatra'][:missing_instances].should == 3
    stats[:runtimes]['ruby19'][:missing_instances].should == 3
  end

  it "should detect extra instances and send a STOP request" do

    timestamp = Time.now.to_i
    version_entry = { indices: {
        0 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '0' },
        1 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '1' },
        2 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '2' },
        3 => { :state => 'RUNNING', :timestamp => timestamp, :last_action => @app.last_updated, :instance => '3' }
    }}

    should_publish_to_nats("cloudcontrollers.hm.requests", {
          'droplet' => @app.id,
          'op' => 'STOP',
          'last_updated' => @app.last_updated.to_i,
          'instances' => [ version_entry[:indices][3][:instance] ]
        })
    @droplet_entry[:versions][@droplet_entry[:live_version]] = version_entry

    stats = analyze_app

    stats[:running].should == 3
    stats[:frameworks]['sinatra'][:running_instances].should == 3
    stats[:runtimes]['ruby19'][:running_instances].should == 3
  end

  it "should update its internal state to reflect heartbeat messages" do
    droplet_entries = @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING"))

    droplet_entries.size.should == 1
    droplet_entry = droplet_entries[0]
    ensure_state_for_live_instance(droplet_entry, 'RUNNING')
  end

  it "should restart an instance that exits unexpectedly" do
    should_publish_start_message

    @hm.process_heartbeat_message(make_heartbeat_message([0], "RUNNING"))
    droplet_entry = induce_crash()
    ensure_state_for_live_instance(droplet_entry, 'DOWN')
  end

  def induce_crash(options = {})
    r = @hm.process_exited_message({
                                 'droplet' => @app.id,
                                 'version' => "#{@app.staged_package_hash}-#{@app.run_count}",
                                 'index' => 0,
                                 'instance' => 0,
                                 'reason' => 'CRASHED',
                                 'crash_timestamp' => Time.now.to_i
                                   }.merge(options).to_json)
    #puts r.to_yaml
    r
  end

  def ensure_state_for_live_instance droplet_entry, state, indices = [0]
    droplet_entry[:versions].should_not be_nil
    version_entry = droplet_entry[:versions][droplet_entry[:live_version]]
    version_entry.should_not be_nil

    indices.each { |i|
      index_entry = version_entry[:indices][i]
      index_entry.should_not be_nil
      index_entry[:state].should == state
    }
  end

  def ensure_state droplet_entry, state
    droplet_entry.should_not be_nil
    droplet_entry[:state].should == state
  end

  def get_droplet
    @hm.get_droplet(@app.id)
  end

  def analyze_app
    stats = { :frameworks => {}, :runtimes => {}, :down => 0, :running => 0 }
    @hm.analyze_app(@app.id, @droplet_entry, stats)
    stats
  end

  it 'should not restart flapping instances' do

    instances = @droplet_entry[:instances]


    instances.times {|i|
      should_publish_start_message('indices'=>[i]).exactly(@flapping_death).times

      @flapping_death.times {
        ensure_state_for_live_instance(induce_crash('index'=>i), 'DOWN', [i])
      }

      @droplet_entry = induce_crash('index'=>i)
      ensure_state_for_live_instance(@droplet_entry, 'FLAPPING', [i])
    }
    analyze_app
  end

  it 'should NOT persist flapping history when not enabled' do

    should_publish_start_message.exactly(@flapping_death).times
    @flapping_death.times { ensure_state_for_live_instance(induce_crash, 'DOWN') }
    ensure_state_for_live_instance(induce_crash, 'FLAPPING')
    #same as the example above, but with a restart of HM.  The history of flapping is forgotten...
    should_publish_start_message 'indices' => [0,1,2]
    create_hm
    build_user_and_app
    analyze_app
    ensure_state(get_droplet, 'STARTED')
  end

  it 'should persist flapping history when enabled' do

    create_hm 'persist_flapping' => true
    build_user_and_app

    should_publish_start_message.exactly(@flapping_death).times
    @flapping_death.times { ensure_state_for_live_instance(induce_crash, 'DOWN') }

    ensure_state_for_live_instance(induce_crash, 'FLAPPING')

    @hm.restore_flapping_status #need to attempt to restore before persisting can happen
    flappers = @hm.persist_flapping_status

    d = get_droplet

    flappers.should == { @app.id => {
        'version' => d[:live_version],
        'timestamp'=> d[:versions][d[:live_version]][:indices].values.map { |i| i[:state_timestamp]}.max
      }}

    create_hm 'persist_flapping' => true
    build_user_and_app

    @hm.update_from_db
    restored_flappers = @hm.restore_flapping_status
    restored_flappers.should == flappers

    analyze_app #should NOT publish a start message
  end

  it 'should not declare flapping if there are non-flapping instances' do

    create_hm 'persist_flapping' => true
    build_user_and_app

    indices = [0,2]

    indices.each do |i|
      should_publish_start_message( 'indices'=>[i] ).exactly(@flapping_death).times
      @flapping_death.times {
        ensure_state_for_live_instance( induce_crash( 'index' => i ), 'DOWN', [i])
      }
      ensure_state_for_live_instance( induce_crash( 'index' => i ), 'FLAPPING', [i])
    end

    @hm.process_heartbeat_message(make_heartbeat_message([0,1,2]-indices, "RUNNING"))

    @hm.restore_flapping_status
    flappers = @hm.persist_flapping_status

    flappers.should == { }

  end

  it 'should be able to run long-running sweep tasks without blocking the EM loop' do

    EM.run do
      EM.next_tick { start_long_running_sweep }
      EM.add_periodic_timer(1) {
        EM.stop if @hm.analysis_complete?
      }
      queue_small_task
    end

    ensure_long_running_sweep_successful
    ensure_sufficient_progress_on_small_tasks
  end

  def queue_small_task
    @small_tasks ||= 0
    @small_tasks += 1
    EM.next_tick { queue_small_task }
  end

  def start_long_running_sweep
    n_users = 100
    n_apps = 2
    clean_db
    build_many_users_and_apps(n_users, n_apps)
    NATS.should_receive(:publish).exactly(n_users * n_apps).times
    @hm.update_from_db
    @hm.analyze_all_apps true
  end

  def ensure_long_running_sweep_successful
    @hm.analysis_complete?.should be_true
  end

  def ensure_sufficient_progress_on_small_tasks
    @small_tasks.should > 10000
  end

end
