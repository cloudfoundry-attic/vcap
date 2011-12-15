$:.unshift(File.join(File.dirname(__FILE__),'..'))
require 'spec_helper'
require 'user_ops'

describe VCAP::UserOps, :needs_root => true do
  before(:all) do
    @test_group = 'test-group'
    @test_user = 'test-user'
    VCAP::UserOps.install_group(@test_group)
  end

  after(:all) do
    VCAP::UserOps.remove_group(@test_group)
  end

  it "adds a user " do
    VCAP::UserOps.install_user(@test_user, @test_group)
    VCAP::UserOps.user_exists?(@test_user).should == true
  end

  it "removes a user " do
    VCAP::UserOps.remove_user(@test_user)
    VCAP::UserOps.user_exists?(@test_user).should == false
  end

end

