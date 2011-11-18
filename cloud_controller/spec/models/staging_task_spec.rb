require 'spec_helper'
require 'uri'

describe StagingTask do
  describe '.create_and_track' do
    before :each do
      StagingTask.untrack_all_tasks
    end

    it 'should return a new StagingTask' do
      app  = create_stub_app(1)
      task = StagingTask.create_and_track(app)
      task.class.should == StagingTask
    end

    it 'should add tasks to the internal tracking hash so they can be looked up later' do
      app = create_stub_app(1)
      task = StagingTask.create_and_track(app)
      StagingTask.find_task(task.task_id).should == task
    end
  end

  describe '.untrack' do
    before :each do
      StagingTask.untrack_all_tasks
    end

    it 'should remove tasks from the internal tracking hash' do
      app = create_stub_app(1)
      task = StagingTask.create_and_track(app)
      StagingTask.find_task(task.task_id).should == task
      StagingTask.untrack(task)
      StagingTask.find_task(task.task_id).should be_nil
    end
  end

  describe '#staging_uri' do
    it 'should correctly set the host and port' do
      CloudController.stubs(:bind_address).returns('127.0.0.1')
      CloudController.stubs(:external_port).returns(12345)
      task = StagingTask.new(create_stub_app(1))
      uri = task.send(:staging_uri, '/test/path')
      parsed_uri = URI.parse(uri)
      parsed_uri.host.should == '127.0.0.1'
      parsed_uri.port.should == 12345
    end
  end

  describe '#user' do
    it 'should be the owner of the app being staged' do
      app = create_stub_app(1, 'test')
      task = StagingTask.new(app)
      task.user.should == app.owner
    end
  end

  def create_stub_app(id, owner=nil)
    app = stub("app_#{id}")
    app.stubs(:id).returns(id)
    app.stubs(:owner).returns(owner)
    app
  end
end
