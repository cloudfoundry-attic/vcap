require 'spec_helper'

describe StagingTaskManager do
  before :all do
    # Prevent EM/NATS related initializers from running
    EM.instance_variable_set(:@next_tick_queue, [])
  end

  describe '#run_staging_task' do
    it 'should expire long running tasks' do
      nats_conn = mock()
      logger = stub_everything(:logger)

      nats_conn.expects(:subscribe).with(any_parameters())
      nats_conn.expects(:unsubscribe).with(any_parameters())

      task = stub_everything(:task)
      VCAP::Stager::Task.expects(:new).with(any_parameters()).returns(task)

      app = create_stub_app(12345)
      stm = StagingTaskManager.new(
        :logger    => logger,
        :nats_conn => nats_conn,
        :timeout   => 1
      )

      res = nil
      EM.run do
        Fiber.new do
          EM.add_timer(2) { EM.stop }
          res = stm.run_staging_task(app, nil, nil)
        end.resume
      end

      res.should be_instance_of(VCAP::Stager::TaskResult)
      res.was_success?.should be_false
    end
  end

  def create_stub_app(id, props={})
    ret = mock("app_#{id}")
    ret.stubs(:id).returns(id)
    ret.stubs(:staging_task_properties).returns(props)
    ret
  end
end
