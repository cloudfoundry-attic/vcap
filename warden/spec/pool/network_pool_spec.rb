require "spec_helper"

describe Warden::Pool::NetworkPool do

  before(:each) do
    @options = { :release_delay => 0.01 }
    @network_pool = Warden::Pool::NetworkPool.new("127.0.0.0", 2, @options)
  end

  it "holds as many addresses as specified" do
    @network_pool.acquire.should == "127.0.0.0"
    @network_pool.acquire.should == "127.0.0.4"
    @network_pool.acquire.should be_nil
  end

  it "delays releasing addresses" do
    a1 = @network_pool.acquire
    a2 = @network_pool.acquire

    # Release a1
    @network_pool.release(a1)

    # Verify it cannot be acquired
    @network_pool.acquire.should be_nil

    # Sleep until the release delay has passed
    sleep @options[:release_delay]

    # Verify it can be acquired
    @network_pool.acquire.should == a1
  end
end
