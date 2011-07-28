require 'spec_helper'

describe VCAP::ProcessUtils do
  describe '.get_stats' do
    it 'should parse fields correctly' do
      VCAP::Subprocess.stub!(:run).and_return(['123 456 7.8', '', 0])
      stats = VCAP::ProcessUtils.get_stats(12345)
      stats[:rss].should   == 123
      stats[:vsize].should == 456
      stats[:pcpu].should  == 7.8
    end

    it "should return nil if the process isn't running" do
      Open3.stub!(:capture3).and_return(['', '', 1])
      stats = VCAP::ProcessUtils.get_stats(12345)
      stats.should be_nil
    end
  end
end
