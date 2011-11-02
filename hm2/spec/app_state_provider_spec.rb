require 'spec_helper'

include HealthManager2

describe HealthManager2 do

  before :all do
    @logger = VCAP::Logging.logger('hm2_spec')
  end


  after :each do
    AppState.remove_all_listeners
  end

  describe AppStateProvider do
    describe AppState do
      before(:each) do
        @id = 1
        @live_version = '123456abcdef'
        @num_instances = 4
        @droplet = AppState.new(@id)
        @droplet.live_version = @live_version
        @droplet.num_instances = @num_instances
        AppState.remove_all_listeners
      end

      it 'should notify before and after listeners' do
        @before_hb_count = 0
        @after_hb_count = 0

        AppState.add_listener :before_heartbeat do
          @before_hb_count += 1
        end
        AppState.add_listener :after_heartbeat do
          @after_hb_count += 1
        end

        beats = make_heartbeat([@droplet])
        beats['droplets'].each { |b|
          @droplet.process_heartbeat(b)
        }
        @before_hb_count.should == @droplet.num_instances
        @after_hb_count.should == @droplet.num_instances
      end

      it 'should calculate missing_indices and invoke event handler' do
        future_answer = [1,3]
        event_handler_invoked = false
        app = AppState.new(1)
        app.num_instances=4

        #no heartbeats arrived yet, so all instances are assumed missing
        app.missing_indices.should == [0,1,2,3]

        AppState.add_listener :instances_missing do |a, indices|
          a.should == app
          indices.should == future_answer
          event_handler_invoked = true
        end

        event_handler_invoked.should be_false
        hbs = make_heartbeat([app])['droplets']

        hbs.delete_at(3)
        hbs.delete_at(1)

        hbs.each {|hb|
          app.process_heartbeat(hb)
        }

        app.missing_indices.should == future_answer
        event_handler_invoked.should be_false

        AppState.analysis_delay_after_reset = 10
        app.analyze

        event_handler_invoked.should be_false

        AppState.analysis_delay_after_reset = 0
        app.analyze

        event_handler_invoked.should be_true
      end
    end
    describe '.get_known_state_provider' do
      it 'should return NATS-based provider by default' do
        AppStateProvider.get_known_state_provider.should be_an_instance_of(NatsBasedKnownStateProvider)
      end
    end
  end
end
