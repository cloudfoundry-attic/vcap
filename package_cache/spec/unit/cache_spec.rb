$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'fileutils'
require 'cache'

describe VCAP::PackageCache::Cache do
  before(:all) do
    enter_test_root
    @cache_dir =  'cache'
    FileUtils.mkdir_p(@cache_dir)
    @test_package = 'testpackage.tgz'
    create_test_file(@test_package)
    @pk = VCAP::PackageCache::Cache.new(@cache_dir)
  end

  after(:all) do
    FileUtils.rm_rf(@cache_dir)
    exit_test_root
  end

  it "should add a package" do
    @pk.add_by_rename!(@test_package)
    @pk.contains?(@test_package).should == true
  end

  it "should remove all packages" do
    @pk.purge!
    @pk.contains?(@test_package).should_not == true
  end
end
