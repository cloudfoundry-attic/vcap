# Copyright (c) 2009-2011 VMware, Inc.
require 'spec_helper'

#functional tests are now implemented in functional/health_manager_spec.rb

describe HealthManager do

  def build_user_and_app
    @user = ::User.find_by_email('test@example.com')
    unless @user
      @user = ::User.new(:email => "test@example.com")
      @user.set_and_encrypt_password('HASHEDPASSWORD')
      @user.save!
    end

    @app = @user.apps.find_by_name('testapp')
    unless @app
      @app = ::App.new(:name => "testapp", :owner => @user, :runtime => "ruby19", :framework => "sinatra")
      @app.package_hash = "f49cf6381e322b147053b74e4500af8533ac1e4c"
      @app.staged_package_hash = "4db6cf8d1d9949790c7e836f29f12dc37c15b3a9"
      @app.state = "STARTED"
      @app.package_state = "STAGED"
      @app.instances = 3
      @app.save!
      @app.set_urls(['http://testapp.vcap.me'])
    end
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
  end

  def should_publish_to_nats(message, payload)
    NATS.should_receive(:publish).with(message, payload.to_json)
  end

  after(:all) do
    #::User.destroy_all
    #::App.destroy_all
  end

  before(:each) do
    @hm = HealthManager.new({
      'mbus' => 'nats://localhost:4222/',
      'logging' => {
        'level' => 'warn',
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
      'dequeueing_rate' => 0,
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

  pending "should not do anything when everything is running" do
    NATS.should_receive(:start).with(:uri => 'nats://localhost:4222/')

    NATS.should_receive(:subscribe).with('dea.heartbeat').and_return { |_, block| @hb_block = block }
    NATS.should_receive(:subscribe).with('droplet.exited')
    NATS.should_receive(:subscribe).with('droplet.updated')
    NATS.should_receive(:subscribe).with('healthmanager.status')
    NATS.should_receive(:subscribe).with('healthmanager.health')
    NATS.should_receive(:publish).with('healthmanager.start')

    NATS.should_receive(:subscribe).with('vcap.component.discover')
    NATS.should_receive(:publish).with('vcap.component.announce', /\{.*\}/)

    EM.run do
      @hm.stub!(:register_error_handler)
      @hm.run

      EM.add_periodic_timer(1) do
        @hb_block.call({:droplets => [
          {
            :droplet => @app.id,
            :version => @app.staged_package_hash,
            :state => :RUNNING,
            :instance => 'instance 1',
            :index => 0
          },
          {
            :droplet => @app.id,
            :version => @app.staged_package_hash,
            :state => :RUNNING,
            :instance => 'instance 2',
            :index => 1
          },
          {
            :droplet => @app.id,
            :version => @app.staged_package_hash,
            :state => :RUNNING,
            :instance => 'instance 3',
            :index => 2
          }
        ]}.to_json)
      end

      EM.add_timer(4.5) do
        EM.stop_event_loop
      end
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

    droplet_entry[:versions].should_not be_nil
    version_entry = droplet_entry[:versions][@droplet_entry[:live_version]]
    version_entry.should_not be_nil
    index_entry = version_entry[:indices][0]
    index_entry.should_not be_nil
    index_entry[:state].should == 'DOWN'
  end
end
