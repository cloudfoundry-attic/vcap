$:.unshift(File.dirname(__FILE__))
require 'spec_helper'

require 'rubygems'
require 'fileutils'

require 'gem_builder'
require 'config'

def uid_to_name(uid)
  Etc.getpwuid(uid).name
end

describe VCAP::PackageCache::GemBuilder do
  before(:all) do
    enter_test_root
    @build_dir =  'build'
    FileUtils.mkdir_p(@build_dir)
    user = {:user_name => uid_to_name(Process.uid), :uid => Process.uid, :gid => Process.gid}
    @test_gem = 'yajl-ruby-0.8.2.gem'
    FileUtils.cp(File.join('../fixtures', @test_gem), @test_gem)
    config_file = VCAP::PackageCache::Config::DEFAULT_CONFIG_PATH
    config = VCAP::PackageCache::Config.from_file(config_file)
    runtimes = config[:runtimes]

    @gbl = VCAP::PackageCache::GemBuilder.new(user, @build_dir, runtimes)
    @gbr = VCAP::PackageCache::GemBuilder.new(user, @build_dir, runtimes)
  end

  after(:all) do
    FileUtils.rm_rf(@build_dir)
    exit_test_root
  end

  it "should build a local gem" do
    @gbl.build(:local, @test_gem, @test_gem, :ruby18)
    package_path = @gbl.get_package
    File.exists?(package_path).should == true
  end

  it "should build a remote gem" do
    @gbr.build(:remote, @test_gem, nil, :ruby18)
    package_path = @gbr.get_package
    File.exists?(package_path).should == true
  end

  it "should remove the package" do
    @gbl.clean_up!
    expect {@gbl.get_package}.to raise_error
  end
end

