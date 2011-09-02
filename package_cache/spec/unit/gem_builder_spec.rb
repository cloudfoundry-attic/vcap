$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'fileutils'

require 'gem_builder'
require 'gem_util'

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
    @gb = VCAP::PackageCache::GemBuilder.new(user, @build_dir)
  end

  after(:all) do
    FileUtils.rm_rf(@build_dir)
    exit_test_root
  end

  it "should import at gem" do
    @gb.import_gem(@test_gem, :rename)
  end

  it "should build a package" do
    @gb.build
    package_path = @gb.get_package
    File.exists?(package_path).should == true
  end

  it "should remove the package" do
    @gb.clean_up!
    expect {@gb.get_package}.to raise_error
  end
end

