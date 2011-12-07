
$:.unshift(File.dirname(__FILE__))
require 'fileutils'

require 'spec_helper'
require 'app_packer'
require 'filesystem_pool'


describe VCAP::UploadManager::AppPacker do
  before(:all) do
    enter_test_root

    @pool_dir = 'test_pool'
    FileUtils.mkdir_p(@pool_dir)
    @file_pool = VCAP::UploadManager::FilesystemPool.new(@pool_dir)

    @pack_dir = 'pack_dir'
    FileUtils.mkdir_p(@pack_dir)
    @test_upload = 'test_upload.zip'
    FileUtils.cp(File.expand_path('../fixtures/test_upload.zip'), @test_upload)
    @packer = VCAP::UploadManager::AppPacker.new(@pack_dir, @file_pool)
  end

  after(:all) do
    FileUtils.rm_rf(@pack_dir)
    exit_test_root
  end

  it "should import a test upload" do
    @packer.import_upload('1234', @test_upload, [])
  end

  it "should package up an app" do
    @packer.package_app
  end

  it "should clean up afterwords" do
    @packer.cleanup!
  end

  it "should import an invalid upload and fail on unpack" do
    @bad_upload = 'bad_upload'
    create_test_file(@bad_upload)
    @packer = VCAP::UploadManager::AppPacker.new(@pack_dir, @file_pool)
    @packer.import_upload('4567', @bad_upload, [])
    expect {@packer.package_app}.to raise_error
  end

end
