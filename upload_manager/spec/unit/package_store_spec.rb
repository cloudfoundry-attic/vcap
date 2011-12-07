
$:.unshift(File.dirname(__FILE__))
require 'fileutils'

require 'spec_helper'
require 'package_store'


describe VCAP::UploadManager::PackageStore do
  before(:all) do
    enter_test_root
    @package_dir = 'package_dir'
    FileUtils.mkdir_p(@package_dir)
    @test_id = '1234'
    @test_file = 'test_file'
    create_test_file(@test_file)
    @store = VCAP::UploadManager::PackageStore.new(@package_dir)
  end

  after(:all) do
    FileUtils.rm_rf(@package_dir)
    exit_test_root
  end

  it "should store a package" do
    @store.put_package(@test_id, @test_file)
    @store.contains?(@test_id).should == true
  end

end
