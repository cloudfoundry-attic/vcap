$:.unshift(File.join(File.dirname(__FILE__),'..'))
require 'user_ops'

if Process.uid != 0
  puts "this test needs to run as root"
  exit
end

describe VCAP::UserOps do
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

