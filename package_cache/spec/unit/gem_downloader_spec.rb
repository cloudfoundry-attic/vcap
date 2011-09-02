$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'fileutils'
require 'gem_downloader'

describe VCAP::PackageCache::GemDownloader do
  before(:all) do
    enter_test_root
    @downloads_dir = 'downloads'
    Dir.mkdir(@downloads_dir)
    @test_gem = 'webmock-1.7.5.gem'
    @gd = VCAP::PackageCache::GemDownloader.new(@downloads_dir)
  end

  after(:all) do
    FileUtils.rm_rf(@downloads_dir)
    exit_test_root
  end

  it "should download a gem" do
    @gd.download(@test_gem)
    @gd.contains?(@test_gem).should == true
  end

  it "return the gem path" do
    File.exists?(@gd.get_gem_path(@test_gem)).should == true
  end

  it "should remove the gem" do
    @gd.remove_gem!(@test_gem)
    @gd.contains?(@test_gem).should == false
  end

  it "should purge its contents"

end
