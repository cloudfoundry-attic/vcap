require File.join(File.dirname(__FILE__), 'spec_helper')

require 'fileutils'
require 'tmpdir'

describe VCAP::Stager::PluginActionProxy do
  before :each do
    @tmpdir = Dir.mktmpdir
  end

  after :each do
    FileUtils.rm_rf(@tmpdir)
  end

  describe '#start_script' do
    it 'should return an open file object with mode 755' do
      start_path = File.join(@tmpdir, 'start')
      proxy = VCAP::Stager::PluginActionProxy.new(start_path, nil, nil)
      verify_script(proxy.start_script)
    end
  end

  describe '#stop_script' do
    it 'should return an open file object with mode 755' do
      stop_path = File.join(@tmpdir, 'stop')
      proxy = VCAP::Stager::PluginActionProxy.new(nil, stop_path, nil)
      verify_script(proxy.stop_script)
    end
  end

  def verify_script(script)
    script.class.should == File
    script.closed?.should be_false
    perms = script.stat.mode & 0xfff
    perms.should == 0755
  end
end
