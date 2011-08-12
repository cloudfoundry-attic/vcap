require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::Stager::TaskLogger do
  describe '#method_missing' do
    it 'should delegate the log method to the vcap logger' do
      args = ['Hello']
      log = mock(:log)
      log.should_receive(:info).with(*args)
      task_log = VCAP::Stager::TaskLogger.new(log)
      task_log.info(*args)
    end
  end
end
