require 'spec_helper.rb'

describe HM2 do

  Manager = HM2::Manager
  Harmonizer = HM2::Harmonizer
  Nudger = HM2::Nudger

  before(:all) do
    EM.error_handler do |e|
      fail "EM error: #{e.message}"
    end
  end

  before(:each) do
    @config = {:intervals =>
      {
        :expected_state_update => 1.5,
      }
    }
    @m = Manager.new(@config)
  end

  describe Harmonizer do
    it 'should be able to describe a policy of bringing a known state to expected state'
  end

  describe Nudger do
    it 'should be able to start app instance' do
      n = Nudger.new
      instances_with_priorities = (1..2).map {|i| [AppState.new(i), 0]}
      NATS.should_receive(:publish).with('cloudcontrollers.hm.requests', an_instance_of(String)).exactly(2).times
      n.start_instances(instances_with_priorities)
      set_env(::HM2::HM_SHADOW, 'false')
      n.deque_batch_of_requests
      restore_env(::HM2::HM_SHADOW)
    end

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
end
