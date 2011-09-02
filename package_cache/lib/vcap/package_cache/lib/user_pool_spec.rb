$:.unshift(File.join(File.dirname(__FILE__)))
require 'user_pool'

describe VCAP::UserPool do
  before(:all) do
    @up = VCAP::UserPool.new(VCAP::UserPool::Defs::TEST_POOL)
    @in_use = []
  end

  it "installs a user pool" do
    @up.install_pool
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

  it "removes a user pool" do
    @up.remove_pool
  end
end

