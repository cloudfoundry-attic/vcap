require 'spec_helper'

describe StagingTaskLog do
  before :all do
    @task_id = 'test_task'
    @task_log = StagingTaskLog.new(@task_id, 'Hello')
    @task_key = StagingTaskLog.key_for_id(@task_id)
  end

  describe '#save' do
    it 'should set a json encoded blob in redis' do
      redis_mock = mock()
      redis_mock.expects(:set).with(@task_key, @task_log.task_log)
      @task_log.save(redis_mock)
    end

    it 'should use the static instance of redis if none is provided' do
      redis_mock = mock()
      redis_mock.expects(:set).with(@task_key, @task_log.task_log)
      StagingTaskLog.redis = redis_mock
      @task_log.save
    end
  end

  describe '#fetch_fibered' do
    before :each do
      @redis_mock = mock()
      @deferrable_mock = EM::DefaultDeferrable.new()
      @deferrable_mock.stubs(:timeout)
      @redis_mock.expects(:get).with(@task_key).returns(@deferrable_mock)
    end

    it 'should fetch and decode an existing task result' do
      Fiber.new do
        res = StagingTaskLog.fetch_fibered(@task_id, @redis_mock)
        res.should be_instance_of(StagingTaskLog)
      end.resume
      @deferrable_mock.succeed(@task_log.task_log)
    end

    it 'should return nil if no key exists' do
      Fiber.new do
        res = StagingTaskLog.fetch_fibered(@task_id, @redis_mock)
        res.should be_nil
      end.resume
      @deferrable_mock.succeed(nil)
    end

    it 'should use the static instance of redis if none is provided' do
      Fiber.new do
        StagingTaskLog.redis = @redis_mock
        res = StagingTaskLog.fetch_fibered(@task_id)
      end.resume
      @deferrable_mock.succeed(nil)
    end

    it 'should raise TimeoutError when timed out fetching result' do
      Fiber.new do
        expect do
          res = StagingTaskLog.fetch_fibered(@task_id, @redis_mock)
        end.to raise_error(VCAP::Stager::TaskError)
      end.resume
      @deferrable_mock.fail(nil)
    end

    it 'should raise error when redis fetching fails' do
      Fiber.new do
        expect do
          res = StagingTaskLog.fetch_fibered(@task_id, @redis_mock)
        end.to raise_error
      end.resume
      @deferrable_mock.fail(RuntimeError.new("Mock Runtime Error from EM::Hiredis"))
    end
  end

end
