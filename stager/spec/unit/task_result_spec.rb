require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::Stager::TaskResult do
  before :all do
    @task_id = 'test_task'
    @task_result = VCAP::Stager::TaskResult.new(@task_id, 0, 'Hello')
    @task_key = VCAP::Stager::TaskResult.key_for_id(@task_id)
  end

  describe '#save' do
    it 'should set a json encoded blob in redis' do
      redis_mock = mock(:redis)
      redis_mock.should_receive(:set).with(@task_key, @task_result.encode)
      @task_result.save(redis_mock)
    end

    it 'should use the static instance of redis if none is provided' do
      redis_mock = mock(:redis)
      redis_mock.should_receive(:set).with(@task_key, @task_result.encode)
      VCAP::Stager::TaskResult.redis = redis_mock
      @task_result.save
    end
  end

  describe '#fetch' do
    it 'should fetch and decode an existing task result' do
      redis_mock = mock(:redis)
      redis_mock.should_receive(:get).with(@task_key).and_return(@task_result.encode)
      res = VCAP::Stager::TaskResult.fetch(@task_id, redis_mock)
      res.should be_instance_of(VCAP::Stager::TaskResult)
    end

    it 'should return nil if no key exists' do
      redis_mock = mock(:redis)
      redis_mock.should_receive(:get).with(@task_key).and_return(nil)
      res = VCAP::Stager::TaskResult.fetch(@task_id, redis_mock)
      res.should be_nil
    end

    it 'should use the static instance of redis if none is provided' do
      redis_mock = mock(:redis)
      redis_mock.should_receive(:get).with(@task_key).and_return(nil)
      VCAP::Stager::TaskResult.redis = redis_mock
      res = VCAP::Stager::TaskResult.fetch(@task_id, redis_mock)
    end
  end
end
