$:.unshift(File.join(File.dirname(__FILE__)))
require 'user_ops'

$test_group = 'test-group'
$test_user = 'test-user'
$test_uid = '65533'

UserOps.init

describe UserOps, "#install_group" do
  it "adds a group to the group file" do
    UserOps.install_group($test_group)
    UserOps.group_exists?($test_group).should == true
  end
end

describe UserOps, "#remove_group" do
  it "removes a group from the group file" do
    UserOps.remove_group($test_group)
    UserOps.group_exists?($test_group).should == false
  end
end

describe UserOps, "#install_user" do
  before(:all) do
    UserOps.install_group($test_group)
  end

  after(:all) do
    UserOps.remove_user($test_user)
    UserOps.remove_group($test_group)
  end

  it "adds a user to the passwd file", :install_user => true  do
    UserOps.install_user($test_user, $test_group, $test_uid)
    UserOps.user_exists?($test_user).should == true
  end
end

describe UserOps, "#remove_user" do
  before(:all) do
    UserOps.install_group($test_group)
    UserOps.install_user($test_user, $test_group, $test_uid)
  end

  after(:all) do
    UserOps.remove_group($test_group)
  end

  it "removes a user from the passwd file" do
    UserOps.remove_user($test_user)
    UserOps.user_exists?($test_user).should == false
  end
end

describe UserOps, "#user_to_uid" do
  before(:all) do
    UserOps.install_group($test_group)
    UserOps.install_user($test_user, $test_group, $test_uid)
  end

  after(:all) do
    UserOps.remove_user($test_user)
    UserOps.remove_group($test_group)
  end

  it "returns correct uid for username" do
    UserOps.user_to_uid($test_user).should == $test_uid
  end
end

# describe UserOps, "#group_to_gid" do
#   before(:all) do
#     UserOps.install_group($test_group)
#   end
#
#   after(:all) do
#     UserOps.remove_group($test_group)
#   end
#
#   it "returns correct uid for username" do
#     UserOps.group_to_gid($test_group).should == XXXX
#   end
# end
#

# need test for user_to_gid
# need test for user_kill_all_procs
# need test for group_kill_all_procs

