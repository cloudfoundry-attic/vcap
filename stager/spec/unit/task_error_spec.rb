require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::Stager::TaskError do
  describe '#to_s' do
    it 'should include the error boilerplate along with any details' do
      dce = VCAP::Stager::DropletCreationError.new
      dce.to_s.should == 'Failed creating droplet'

      dce = VCAP::Stager::DropletCreationError.new('xxx')
      dce.to_s.should == "Failed creating droplet:\n xxx"
    end
  end
end
