$:.unshift(File.join(File.dirname(__FILE__),'..'))
require 'spec_helper'
require 'user_pool_util'

describe VCAP::UserPoolUtil, :needs_root => true do
  before(:all) do
    pending "this test needs to run as root" if Process.uid != 0
    VCAP::UserPoolUtil.init
  end

  it "installs a user pool" do
    VCAP::UserPoolUtil.install_pool('test_pool', 5)
    VCAP::UserPoolUtil.install_pool('test_pool2', 5)
  end

  it "opens a user pool" do
    VCAP::UserPoolUtil.open_pool('test_pool').size.should == 5
  end

  it "lists user pools" do
    list = VCAP::UserPoolUtil.pool_list
    puts list
    VCAP::UserPoolUtil.pool_list.size.should == 2
  end

  it "removes a user pool" do
    VCAP::UserPoolUtil.remove_pool('test_pool')
    VCAP::UserPoolUtil.remove_pool('test_pool2')
  end
end

