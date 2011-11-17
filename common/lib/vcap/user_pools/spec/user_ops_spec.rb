$:.unshift(File.join(File.dirname(__FILE__),'..'))
require 'user_ops'

$test_group = 'test-group'
$test_user = 'test-user'

describe VCAP::UserOps, "#install_group" do
  it "adds a group to the group file" do
    VCAP::UserOps.install_group($test_group)
    VCAP::UserOps.group_exists?($test_group).should == true
  end
end

describe VCAP::UserOps, "#remove_group" do
  it "removes a group from the group file" do
    VCAP::UserOps.remove_group($test_group)
    VCAP::UserOps.group_exists?($test_group).should == false
  end
end

describe VCAP::UserOps, "#install_user" do
  before(:all) do
    VCAP::UserOps.install_group($test_group)
  end

  after(:all) do
    VCAP::UserOps.remove_user($test_user)
    VCAP::UserOps.remove_group($test_group)
  end

  it "adds a user to the passwd file", :install_user => true  do
    VCAP::UserOps.install_user($test_user, $test_group)
    VCAP::UserOps.user_exists?($test_user).should == true
  end
end

describe VCAP::UserOps, "#remove_user" do
  before(:all) do
    VCAP::UserOps.install_group($test_group)
    VCAP::UserOps.install_user($test_user, $test_group)
  end

  after(:all) do
    VCAP::UserOps.remove_group($test_group)
  end

  it "removes a user from the passwd file" do
    VCAP::UserOps.remove_user($test_user)
    VCAP::UserOps.user_exists?($test_user).should == false
  end
end


# need test for user_kill_all_procs
# need test for group_kill_all_procs

