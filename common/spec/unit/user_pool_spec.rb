$:.unshift(File.dirname(__FILE__),'..')
require 'spec_helper'
require 'user_pool_util'
require 'user_pool'
require 'em_fiber_wrap'

describe VCAP::UserPool, :needs_root => true do
  before(:all) do
    VCAP::UserPoolUtil.init
    em_fiber_wrap{ VCAP::UserPoolUtil.install_pool('test_pool', 5)}
    @up = VCAP::UserPool.new('test_pool')
    @in_use = []
  end

  after(:all) do
    em_fiber_wrap{ VCAP::UserPoolUtil.remove_pool('test_pool')}
  end

  it "allocates some users" do
    @in_use.push @up.alloc_user
    @in_use.push @up.alloc_user
    @in_use.push @up.alloc_user
  end

  it "free's some users" do
    em_fiber_wrap { @up.free_user @in_use.pop }
    em_fiber_wrap { @up.free_user @in_use.pop }
    em_fiber_wrap { @up.free_user @in_use.pop }
  end

end

