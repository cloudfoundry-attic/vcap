require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::Stager::TaskManager do
  describe '#start_tasks'do
    it 'should start as many tasks as allowed' do
      tm = VCAP::Stager::TaskManager.new(3)
      tasks = []
      for ii in 0..2
        t = make_mock_task(ii)
        t.should_receive(:perform).with(any_args())
        tasks << t
      end
      t = make_mock_task(3)
      t.should_not_receive(:perform)
      tasks << t
      # XXX :(
      tm.instance_variable_set(:@queued_tasks, tasks)
      tm.send(:start_tasks)
    end

    it 'should update varz' do
      tm = VCAP::Stager::TaskManager.new(2)
      tasks = []
      for ii in 0..1
        t = make_mock_task(ii)
        t.should_receive(:perform).with(any_args())
        tasks << t
      end
      for ii in 2..3
        tasks << make_mock_task(ii)
      end
      # XXX :(
      tm.instance_variable_set(:@queued_tasks, tasks)

      varz = {}
      tm.varz = varz
      tm.send(:start_tasks)
      varz[:num_pending_tasks].should == 2
      varz[:num_active_tasks].should == 2
    end

    it 'should checkout a secure user per task' do
      um = mock(:secure_user_manager)
      um.should_receive(:checkout_user).twice()
      tm = VCAP::Stager::TaskManager.new(3, um)
      tasks = []
      for ii in 0..1
        t = make_mock_task(ii)
        t.should_receive(:perform).with(any_args())
        t.should_receive(:user=).with(nil)
        tasks << t
      end
      tm.instance_variable_set(:@queued_tasks, tasks)
      tm.send(:start_tasks)
    end
  end

  describe '#task_completed' do
    it 'should emit a task_completed event' do
      tm = VCAP::Stager::TaskManager.new(3)
      task = make_mock_task(1)
      task.stub(:user).and_return(nil)
      tm.should_receive(:event).with(:task_completed, task, 'test')
      tm.should_receive(:event).with(:idle)
      tm.send(:task_completed, task, 'test')
    end
  end

  def make_mock_task(id)
    t = mock("task_#{id}")
    t.stub(:task_id).and_return(id)
    t
  end
end
