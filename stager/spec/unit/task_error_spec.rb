require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::Stager::TaskError do
  describe '#encode' do
    it 'should encode the error as json' do
      se = VCAP::Stager::StagingPluginError.new('xxx')
      dec_se = Yajl::Parser.parse(se.encode)
      dec_se['class'].should == 'VCAP::Stager::StagingPluginError'
      dec_se['details'].should == 'xxx'
    end
  end

  describe '#decode' do
    it 'should decode errors and return an instance of the appropriate error' do
      se = VCAP::Stager::DropletCreationError.new
      dec_se = VCAP::Stager::TaskError.decode(se.encode)
      dec_se.class.should == VCAP::Stager::DropletCreationError
      dec_se.details.should be_nil
    end

    it 'should decode details if set' do
      dce = VCAP::Stager::DropletCreationError.new('xxx')
      dec_dce = VCAP::Stager::TaskError.decode(dce.encode)
      dec_dce.details.should == 'xxx'
    end
  end

  describe '#to_s' do
    it 'should include the error boilerplate along with any details' do
      dce = VCAP::Stager::DropletCreationError.new
      dce.to_s.should == 'Failed creating droplet'

      dce = VCAP::Stager::DropletCreationError.new('xxx')
      dce.to_s.should == "Failed creating droplet:\n xxx"
    end
  end
end
