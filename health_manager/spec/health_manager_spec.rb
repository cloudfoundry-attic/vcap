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
  end

  after(:all) do
    #::User.destroy_all
    #::App.destroy_all
  end

  before(:each) do
    @hm = HealthManager.new({
      'mbus' => 'nats://localhost:4222/',
      'log_level' => 'FATAL',
      'intervals' => {
        'database_scan' => 1,
        'droplet_lost' => 3,
        'droplets_analysis' => 0.5,
        'flapping_death' => 3,
        'flapping_timeout' => 5,
        'restart_timeout' => 2,
        'stable_state' => 1
      }
    })

    hash = Hash.new {|h,k| h[k] = 0}
    VCAP::Component.stub!(:varz).and_return(hash)
    build_user_and_app

    silence_warnings { NATS = mock("NATS") }
    NATS.should_receive(:start).with(:uri => 'nats://localhost:4222/')

    NATS.should_receive(:subscribe).with('dea.heartbeat').and_return { |_, block| @hb_block = block }
    NATS.should_receive(:subscribe).with('droplet.exited')
    NATS.should_receive(:subscribe).with('droplet.updated')
    NATS.should_receive(:subscribe).with('healthmanager.status')
    NATS.should_receive(:subscribe).with('healthmanager.health')
    NATS.should_receive(:publish).with('healthmanager.start')

    NATS.should_receive(:subscribe).with('vcap.component.discover')
    NATS.should_receive(:publish).with('vcap.component.announce', /\{.*\}/)
  end

  pending "should not do anything when everything is running" do
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
end
