$:.unshift(File.dirname(__FILE__),'..')

require 'spec_helper'

describe VCAP::Quota, :needs_root => true, :needs_quota => true do
  before :all do
    @test_fs   = ENV['QUOTA_TEST_FS']
    @test_user = ENV['QUOTA_TEST_USER']
    @test_uid  = Etc.getpwnam(@test_user).uid
  end

  it 'should set and retrieve quotas' do
    cmd = VCAP::Quota::SetQuota.new
    cmd.filesystem = @test_fs
    cmd.user = @test_user
    cmd.quotas[:block][:hard] = 123456
    status, stdout = cmd.run
    status.should == 0

    cmd = VCAP::Quota::RepQuota.new
    cmd.filesystem = @test_fs
    success, details = cmd.run
    success.should be_true
    details[@test_user][:quotas][:block][:hard].should == 123456
  end

  it 'should return uids as integer keys when asked' do
    cmd = VCAP::Quota::SetQuota.new
    cmd.filesystem = @test_fs
    cmd.user = @test_user
    cmd.quotas[:block][:hard] = 123456
    status, stdout = cmd.run
    status.should == 0

    cmd = VCAP::Quota::RepQuota.new
    cmd.filesystem = @test_fs
    cmd.ids_only = true
    success, details = cmd.run
    success.should be_true
    details[@test_uid][:quotas][:block][:hard].should == 123456
  end
end
