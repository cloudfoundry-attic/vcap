$:.unshift(File.dirname(__FILE__))
require 'spec_helper'

require 'rubygems'
require 'eventmachine'
require 'fileutils'
require 'fiber'

require 'pip_builder'

def uid_to_name(uid)
  Etc.getpwuid(uid).name
end

describe VCAP::PackageCache::PipBuilder do
  before(:all) do
    enter_test_root
    @build_dir =  'build'
    FileUtils.mkdir_p(@build_dir)
    user = {:user_name => uid_to_name(Process.uid), :uid => Process.uid, :gid => Process.gid}
    @test_pip = 'fluentxml-0.1.1.pip'
    FileUtils.cp(File.join('../fixtures', @test_pip), @test_pip)
    @pb = VCAP::PackageCache::PipBuilder.new(user, @build_dir)
  end

  after(:all) do
    FileUtils.rm_rf(@build_dir)
    exit_test_root
  end

  it "should import a pip" do
    @pb.import_package_src(@test_pip)
  end

  it "should build a package" do
    em_fiber_wrap { @pb.build }
    package_path = @pb.get_package
    File.exists?(package_path).should == true
    puts "tail of package contents for #{package_path}...\n"
    puts `tar tzvf #{package_path} | tail -10`
  end

  it "should remove the package" do
    @pb.clean_up!
    expect {@pb.get_package}.to raise_error
  end
end

