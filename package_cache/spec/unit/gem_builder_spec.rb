$:.unshift(File.dirname(__FILE__))
require 'spec_helper'

require 'rubygems'
require 'eventmachine'
require 'fileutils'
require 'fiber'

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

  it "should import a gem" do
    @gb.import_package_src(@test_gem)
  end

  it "should build a package" do
    em_fiber_wrap { @gb.build }
    package_path = @gb.get_package
    File.exists?(package_path).should == true
    puts "tail of package contents for #{package_path}...\n"
    puts `tar tzvf #{package_path} | tail -10`
  end

  it "should remove the package" do
    @gb.clean_up!
    expect {@gb.get_package}.to raise_error
  end
end

