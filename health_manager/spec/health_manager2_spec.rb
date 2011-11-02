require '../lib/health_manager2.rb'

include HealthManager2

describe HealthManager2 do

  before(:all) do
    EM.error_handler do |e|
      puts "EM error: #{e.message}"
    end
  end

  before(:each) do
    #NATS = mock('NATS')

    @config = {:intervals =>
      {
        :expected_state_update => 3,
        :nats_ping => 1}}

    @m = Manager.new(@config)
  end

  describe AppStateProvider do
    it 'should answer questions about App State'
  end

  describe Harmonizer do
    it 'should be able to describe a policy of bringing a known state to expected state'
  end

  describe Nudger do
    it 'should be able to start app instance'
    it 'should be able to stop app instance'
  end


  def expect_within(time, manager)
    EM.run do
      EM.add_timer(time) do
        EM.stop
      end
      yield
      manager.start
    end
  end

  describe Manager do
    it 'should use Harmonizer and Scheduler to request Nudger to nudge Known State into Expected State'

    describe '#schedule' do
      it 'should schedule nats.ping' do
        m = Manager.new :intervals =>
          { :nats_ping => 0.1 }

        expect_within(2, m) do
          m.schedule
          NATS.should_receive(:publish).with('healthmanager.nats.ping', an_instance_of(String)).at_least(8).times
        end
      end
    end

    describe '#get_interval' do
      it 'should return configured interval values' do
        m1 = Manager.new( :intervals => {:nats_ping =>5 } )
        m2 = Manager.new( 'intervals' => {'nats_ping' =>6 } )

        m1.get_interval(:nats_ping).should == 5
        m1.get_interval('nats_ping').should == 5
        m2.get_interval(:nats_ping).should == 6
        m2.get_interval('nats_ping').should == 6
      end

      it 'should return default interval values' do
        m = Manager.new
        m.get_interval(:nats_ping).should == NATS_PING
        m.get_interval('nats_ping').should == NATS_PING
      end

      it 'should raise ArgumentError for invalid intervals' do
        lambda { @m.get_interval(:bogus) }.should raise_error(ArgumentError, /undefined interval/)
      end
    end
  end
end
