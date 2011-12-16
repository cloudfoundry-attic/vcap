require '../lib/nats_based_known_state_provider.rb'

include HealthManager2

describe HealthManager2 do
  describe AppStateProvider do

    describe AppState do
      before(:each) do
        @id = 1
        @live_version = '123456abcdef'
        @instances = 4
        @droplet = AppState.new(@id)
        @droplet.live_version = @live_version
        @droplet.instances = @instances
        AppState.remove_all_listeners
      end

      it 'should track changing attrbutes' do
        @droplet.live_version_changed?(@live_version).should be_false
        @droplet.live_version_changed?(@live_version+'abc').should be_true

        @droplet.instances_changed?(@instances).should be_false
        @droplet.instances_changed?(@instances+2).should be_true
      end

      it 'should notify listeners' do

        @before_hb_count = 0
        @after_hb_count = 0

        AppState.add_listener :before_heartbeat do
          @before_hb_count += 1
        end
        AppState.add_listener :after_heartbeat do
          @after_hb_count += 1
        end

        beats = parse_json(make_heartbeat([@droplet]))
        beats['droplets'].each { |b|
          @droplet.process_heartbeat(b)
        }
        @before_hb_count.should == @droplet.instances
        @after_hb_count.should == @droplet.instances
      end

    end

    describe '.get_known_state_provider' do
      it 'should return NATS-based provider by default' do
        AppStateProvider.get_known_state_provider.should be_an_instance_of(NatsBasedKnownStateProvider)
      end
    end

    describe NatsBasedKnownStateProvider do
      before(:each) do
        @nb = NatsBasedKnownStateProvider.new
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

        heartbeat = make_heartbeat([alive])
        @nb.process_heartbeat(heartbeat)
        #puts @nb.to_yaml

        @nb.get_state(alive.id).should == STARTED

      end
    end
  end

  def make_heartbeat(apps)

    hb = []
    apps.each do |app|
      app.instances.times {|index|
        hb << {
          'droplet' => app.id,
          'version' => app.live_version,
          'instance' => "#{app.live_version}-#{index}",
          'index' => index,
          'state' => app.state,
          'state_timestamp' => now
        }
      }
    end
    {'droplets' => hb}.to_json

  end

  def make_app(options={})

    @app_id ||= 0
    @app_id += 1
    @version = '123456'

    app = AppState.new(@app_id)

    {
      'instances' => 2,
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

  def now
    @now || Time.now.to_i
  end
end
