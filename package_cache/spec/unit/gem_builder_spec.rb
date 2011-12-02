
$:.unshift(File.dirname(__FILE__))
require 'spec_helper'

require 'rubygems'
require 'eventmachine'
require 'fileutils'
require 'fiber'

require 'gem_builder'



def uid_to_name(uid)
  Etc.getpwuid(uid).name
end

describe VCAP::PackageCache::GemBuilder, :needs_root => true do
  before(:all) do
    enter_test_root
    @build_dir =  'build'
    FileUtils.mkdir_p(@build_dir)
    user = {:user_name => uid_to_name(Process.uid), :uid => Process.uid, :gid => Process.gid}
    @test_gem = 'yajl-ruby-0.8.2.gem'
    FileUtils.cp(File.join('../fixtures', @test_gem), @test_gem)
    @gbl = VCAP::PackageCache::GemBuilder.new(user, @build_dir)
    @gbr = VCAP::PackageCache::GemBuilder.new(user, @build_dir)
  end

  after(:all) do
    FileUtils.rm_rf(@build_dir)
    exit_test_root
  end

  it "should build a local gem" do
    em_fiber_wrap { @gbl.build(:local, @test_gem, @test_gem) }
    package_path = @gbl.get_package
    File.exists?(package_path).should == true
  end

  it "should build a remote gem" do
    em_fiber_wrap { @gbr.build(:remote, @test_gem) }
    package_path = @gbr.get_package
    File.exists?(package_path).should == true
  end

  it "should remove the package" do
    @gbl.clean_up!
    expect {@gbl.get_package}.to raise_error
  end
end

