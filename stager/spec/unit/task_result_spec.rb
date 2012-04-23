require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::Stager::TaskResult do
  describe '#encode' do
    it 'should encode the task result as json' do
      tr = VCAP::Stager::TaskResult.new('xxx', 'yyy')
      dec_tr = Yajl::Parser.parse(tr.encode)
      dec_tr['task_id'].should == tr.task_id
      dec_tr['task_log'].should == tr.task_log
      dec_tr['error'].should == nil
    end

    it 'should encode the associated error if supplied' do
      err = mock(:task_error)
      err.should_receive(:encode)
      VCAP::Stager::TaskResult.new('xxx', 'yyy', err).encode
    end
  end

  describe '.decode' do
    it 'should decode encoded task results' do
      tr = VCAP::Stager::TaskResult.new('xxx', 'yyy', VCAP::Stager::TaskError.new)
      dec_tr = VCAP::Stager::TaskResult.decode(tr.encode)
      dec_tr.task_id.should == tr.task_id
      dec_tr.task_log.should == tr.task_log
      dec_tr.error.class.should == VCAP::Stager::TaskError
    end
  end
end
