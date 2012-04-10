$:.unshift(File.dirname(__FILE__),'..')
require 'spec_helper'
require 'user_pool_util'
require 'user_pool'

describe VCAP::UserPool, :needs_root => true do
  before(:all) do
    VCAP::UserPoolUtil.init
    VCAP::UserPoolUtil.install_pool('test_pool', 5)
    @up = VCAP::UserPool.new('test_pool')
    @in_use = []
  end

  after(:all) do
    VCAP::UserPoolUtil.remove_pool('test_pool')
  end

  it "allocates some users" do
    @in_use.push @up.alloc_user
    @in_use.push @up.alloc_user
    @in_use.push @up.alloc_user
  end

  it "free's some users" do
    @up.free_user @in_use.pop
    @up.free_user @in_use.pop
    @up.free_user @in_use.pop
  end

end

