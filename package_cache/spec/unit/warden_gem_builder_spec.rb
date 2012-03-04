$:.unshift(File.dirname(__FILE__))
require 'spec_helper'

require 'rubygems'
require 'fileutils'
require 'config'

require 'warden_env'
require 'warden_gem_builder'

describe VCAP::PackageCache::GemBuild, :needs_warden => true do
  before(:all) do
    enter_test_root
    @test_gem = 'yajl-ruby-0.8.2.gem'
    @test_gem_path = File.expand_path(File.join('../fixtures', @test_gem))
    config_file = VCAP::PackageCache::Config::DEFAULT_CONFIG_PATH
    config = VCAP::PackageCache::Config.from_file(config_file)
    runtimes = config[:runtimes]
    env_l = VCAP::PackageCache::WardenEnv.new(runtimes)
    env_r = VCAP::PackageCache::WardenEnv.new(runtimes)
    @gbl = VCAP::PackageCache::GemBuild.new(env_l, :ruby19)
    @gbr = VCAP::PackageCache::GemBuild.new(env_r, :ruby19)
  end

  after(:all) do
    @gbl.clean_up!
    @gbr.clean_up!
    exit_test_root
  end

  it "should import a local gem" do
    @gbl.copy_in_pkg_src(@test_gem_path, @test_gem)
  end

  it "should build a local gem" do
    @gbl.build(:local, @test_gem)
  end

  it "should package a gem" do
    @package_path = @gbl.create_package(@test_gem, :ruby19)
    package_dst = File.join(Dir.pwd, File.basename(@package_path))
    @gbl.copy_out_pkg(@package_path, package_dst)
    File.exists?(package_dst).should == true
  end

  it "should build a remote gem" do
    @gbr.build(:remote, @test_gem)
  end

end

