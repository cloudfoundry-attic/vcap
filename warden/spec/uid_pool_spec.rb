require 'spec_helper'

describe Warden::Container::UidPool, :needs_root => true do
  before :all do
    @pool_name = 'warden-uidpool-test'
  end

  describe '.acquire' do
    before :each do
      destroy_pool(@pool_name)
    end

    after :each do
      destroy_pool(@pool_name)
    end

    it 'should create a pool if it does not exist' do
      acquire_pool(@pool_name, 2)
      verify_pool(@pool_name, 2)
    end

    it 'should expand existing pools' do
      acquire_pool(@pool_name, 2)
      verify_pool(@pool_name, 2)

      # Grow to 4
      acquire_pool(@pool_name, 4)
      verify_pool(@pool_name, 4)
    end
  end

  describe '#acquire' do
    before :each do
      destroy_pool(@pool_name)
    end

    after :each do
      destroy_pool(@pool_name)
    end

    it 'should return a uid if one is available' do
      pool = acquire_pool(@pool_name, 2)
      verify_pool(@pool_name, 2)
      pool.acquire.should_not be_nil
    end

    it 'should raise NoUidAvailable if no uids are available' do
      pool = acquire_pool(@pool_name, 1)
      verify_pool(@pool_name, 1)
      pool.acquire.should_not be_nil
      expect do
        pool.acquire
      end.to raise_error(Warden::Container::UidPool::NoUidAvailable)
    end
  end

  describe '#release' do
    before :each do
      destroy_pool(@pool_name)
    end

    after :each do
      destroy_pool(@pool_name)
    end

    it 'should return a uid to the pool' do
      pool = acquire_pool(@pool_name, 1)
      verify_pool(@pool_name, 1)
      uid = pool.acquire
      uid.should_not be_nil
      expect do
        pool.acquire
      end.to raise_error(Warden::Container::UidPool::NoUidAvailable)
      pool.release(uid)
      uid = pool.acquire
      uid.should_not be_nil
    end
  end

  def acquire_pool(name, count, timeout=2)
    ret = nil
    em_fibered(:timeout => timeout) do
      ret = Warden::Container::UidPool.acquire(name, count)
      EM.stop
    end
    ret
  end

  def destroy_pool(name)
    em_fibered do
      Warden::Container::UidPool.destroy(name)
      EM.stop
    end
    Warden::Container::UidPool.find_group(name).should be_nil
    Warden::Container::UidPool.find_users(name).empty?.should be_true
  end

  def verify_pool(name, count)
    group = Warden::Container::UidPool.find_group(@pool_name)
    group.should_not be_nil
    group.name.should == name
    Warden::Container::UidPool.find_users(@pool_name).length.should == count
  end
end
