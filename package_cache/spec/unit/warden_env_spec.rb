$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'warden_env'

describe VCAP::PackageCache::WardenEnv , :needs_warden => true do
  before(:all) do
    enter_test_root
    @test_package = 'yajl-ruby-0.8.2.gem'
    @test_package_path = File.expand_path(File.join('../fixtures', @test_package))
    @builder = VCAP::PackageCache::WardenEnv.new
  end
  after(:all) do
    @builder.destroy!
    exit_test_root
  end

  it "copy in a file and check the file exists" do
    @builder.copy_in(@test_package_path, @test_package)
    @builder.file_exists?(@test_package).should == true
  end

  it "copy out a file" do
    @builder.copy_out(@test_package, File.join(Dir.pwd, @test_package))
    File.exists?(@test_package).should == true
  end

  it "run a command" do
    status, out, err = @builder.run("echo foo")
    out.chop.should == 'foo'
  end

end

