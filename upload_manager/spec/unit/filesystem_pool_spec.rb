$:.unshift(File.dirname(__FILE__))
require 'fileutils'

require 'spec_helper'
require 'filesystem_pool'



describe VCAP::UploadManager::FilesystemPool do
  before(:all) do
    enter_test_root
    @test_file = 'test_file'
    @test_dir =  File.expand_path('../fixtures/sample_dir')
    @pool_dir = 'test_pool'
    create_test_file(@test_file)
    FileUtils.mkdir_p(@pool_dir)
    @fp = VCAP::UploadManager::FilesystemPool.new(@pool_dir)
  end

  after(:all) do
    FileUtils.rm_rf(@pool_dir)
    exit_test_root
  end

  it "should test if a file is a valid canidate" do
    @fp.valid_file?(@test_file).should == true
  end

  it "should add a test file to the pool" do
    desc = @fp.file_to_descriptor(@test_file)
    @fp.add_path(@test_file)
    @fp.contains?(desc).should == true
  end

  it "should match a descriptor list against pool contents" do
    desc = @fp.file_to_descriptor(@test_file)
    @fp.match_resources([desc]).should == [desc]
  end

  it "should add the sample directory to the pool" do
    @fp.add_directory(@test_dir)
    pattern = File.join(@test_dir, '**', '*')
    Dir.glob(pattern).each do |path|
      desc = @fp.file_to_descriptor(path)
      @fp.contains?(desc).should == true
    end
  end

  it "should retrieve a file" do
    @fp.add_path(@test_file)
    desc = @fp.file_to_descriptor(@test_file)
    file_out = @test_file + '.out'
    @fp.retrieve_file(desc, file_out)
    File.open(@test_file).read.should == File.open(file_out).read
  end

end
