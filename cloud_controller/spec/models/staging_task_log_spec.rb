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

  describe '#fetch' do
    it 'should fetch and decode an existing task result' do
      redis_mock = mock()
      redis_mock.expects(:get).with(@task_key).returns(@task_log.task_log)
      res = StagingTaskLog.fetch(@task_id, redis_mock)
      res.should be_instance_of(StagingTaskLog)
    end

    it 'should return nil if no key exists' do
      redis_mock = mock()
      redis_mock.expects(:get).with(@task_key).returns(nil)
      res = StagingTaskLog.fetch(@task_id, redis_mock)
      res.should be_nil
    end

    it 'should use the static instance of redis if none is provided' do
      redis_mock = mock()
      redis_mock.expects(:get).with(@task_key).returns(nil)
      StagingTaskLog.redis = redis_mock
      res = StagingTaskLog.fetch(@task_id, redis_mock)
    end
  end
end
