$:.unshift(File.dirname(__FILE__),'..')
require 'user_pool_util'
require 'user_pool'
require 'em_fiber_wrap'

if Process.uid != 0
  puts "this test needs to run as root"
  exit
end

describe VCAP::UserPool do
  before(:all) do
    if Process.uid != 0
      pending "this test needs to run as root"
    end
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

