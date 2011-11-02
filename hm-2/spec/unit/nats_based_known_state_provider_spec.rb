require 'spec_helper'
include HealthManager2

describe HealthManager2 do
  before :all do
    @logger = get_logger('hm-2_spec')
  end

  after :each do
    AppState.remove_all_listeners
    set_now(nil)
  end

  describe AppStateProvider do
    describe NatsBasedKnownStateProvider do

      class NatsBasedKnownStateProvider
        attr_reader :apps_in_dea
      end

      before(:each) do
        @nb = NatsBasedKnownStateProvider.new(build_valid_config(dea_timeout_interval: 0.2))
      end

      it 'should subscribe to heartbeat and droplet.exited messages' do
        NATS.should_receive(:subscribe).with('dea.heartbeat')
        NATS.should_receive(:subscribe).with('droplet.exited')
        @nb.start
      end

      it 'should update state according to the heartbeat messages' do
        alive = make_app( 'state' => STARTED )
        @nb.get_state(alive.id).should be_nil #unknown state
        @nb.set_state(alive.id, STOPPED)
        @nb.get_state(alive.id).should == STOPPED

        state_changed = false
        AppState.add_listener :state_changed do |*args|
          state_changed = true
        end

        heartbeat = make_heartbeat([alive])
        @nb.process_heartbeat(heartbeat.to_json)

        state_changed.should be_true #ensures the event listener has been called
        @nb.get_state(alive.id).should == STARTED
      end

      it 'WIP: should trigger missing instances check' do
        missing_indices_invoked = false

        AppState.add_listener :instances_missing do |a, indices|
          indices.should == [0,2]
          missing_indices_invoked = true
        end

        AppState.heartbeat_deadline = 5
        set_now(666)

        app1 = make_app({'num_instances' => 4 })

        @logger.debug("app just created: #{app1.inspect}")


        hb = make_heartbeat([app1])
        @nb.process_heartbeat(hb.to_json)

        app1 = @nb.get_droplet(app1.id)

        @logger.debug("app after proper hb: #{app1.inspect}")

        hb['droplets'].delete_at(2)
        hb['droplets'].delete_at(0)

        missing_indices_invoked.should be_false
        @logger.debug("app before analysis : #{app1.inspect}")
        app1.analyze
        @logger.debug("app after analysis : #{app1.inspect}")
        missing_indices_invoked.should be_false
        set_now(666 + 6)
        @nb.process_heartbeat(hb.to_json)

        app1.analyze

        @logger.debug("app after short h/b processed : #{app1.inspect}")
        missing_indices_invoked.should be_true
      end
    end
  end


  def make_app(options={})
    @app_id ||= 0
    @app_id += 1
    @version = '123456'
    app = AppState.new(@app_id)
    {
      'num_instances' => 2,
      'framework' => 'sinatra',
      'runtime' => 'ruby18',
      'live_version' => @version,
      'state' => STARTED,
      'last_updated' => now

    }.merge(options).each { |k,v|
      app.send "#{k}=", v
    }
    app
  end

  def build_valid_config(config={})
    @config = config
    register_hm_component(:scheduler, @scheduler = Scheduler.new(@config), @config)
    @config
  end
end
