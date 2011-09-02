
$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'fileutils'
require 'downloader'
require 'gem_util'
require 'pip_util'

describe VCAP::PackageCache::Downloader do
  before(:all) do
    enter_test_root
    @downloads_dir = 'downloads'
    Dir.mkdir(@downloads_dir)
    @test_gem = 'webmock-1.7.5.gem'
    @test_pip = 'fluentxml-0.1.1'
    @gd = VCAP::PackageCache::Downloader.new(@downloads_dir)
    @test_gem_url = GemUtil.gem_to_url(@test_gem)
    @test_pip_url = PipUtil.pip_to_url(@test_pip)
  end

  after(:all) do
    FileUtils.rm_rf(@downloads_dir)
    exit_test_root
  end

  it "should download a gem" do
    em_fiber_wrap{ @gd.download(@test_gem, @test_gem_url) }
    @gd.contains?(@test_gem).should == true
  end

  it "should download a python package" do
    em_fiber_wrap{ @gd.download(@test_pip, @test_pip_url) }
    @gd.contains?(@test_pip).should == true
  end

  it "return the gem path" do
    File.exists?(@gd.get_file_path(@test_gem)).should == true
  end

  it "should remove the gem" do
    @gd.remove_file!(@test_gem)
    @gd.contains?(@test_gem).should == false
  end

  it "should purge its contents"

end
