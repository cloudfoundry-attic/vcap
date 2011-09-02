$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'fileutils'
require 'inbox'

describe VCAP::PackageCache::Inbox do
  before(:all) do
    enter_test_root
    @inbox_dir =  'inbox'
    FileUtils.mkdir_p(@inbox_dir)

    test_module = 'fake.gem'
    create_test_file(test_module)
    @ib = VCAP::PackageCache::Inbox.new(@inbox_dir, :server)
    @entry_name = @ib.add_entry(test_module)
  end

  after(:all) do
    FileUtils.rm_rf(@inbox_dir)
    exit_test_root
  end


  it "should add new inbox entries" do
    @ib.public_contains?(@entry_name).should == true
  end

  it "it should import a new entry" do
    @ib.secure_import_entry(@entry_name)
  end

  it "should return the path for the entry" do
    @ib.get_private_entry(@entry_name).should_not == nil
  end

  it "should purge its contents" do
    @ib.purge!
    @ib.private_contains?(@entry_name).should_not == true
   end

end

