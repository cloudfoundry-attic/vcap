require "spec_helper"

shared_context :server_lxc do

  include_context :warden_server
  include_context :warden_client

  let(:container_klass) {
    Warden::Container::LXC
  }

  let(:quota_config) {
    nil
  }

  let (:client) {
    create_client
  }
end

describe "server implementing LXC" do
  it_behaves_like "a warden server", Warden::Container::LXC

  describe 'when configured with quota support', :needs_quota_config => true do

    include_context :server_lxc

    let(:quota_config) {
      { :uidpool => {
          :name => 'warden-lxc-uidpool-server-test',
          :count => 1,
        },
        :filesystem => ENV['WARDEN_TEST_QUOTA_FS'],
        :check_interval => 0.25,
        :report_quota_path => ENV['WARDEN_TEST_REPORT_QUOTA_PATH'],
      }
    }

    it 'allocates a user per container' do
      handle = client.call("create")
      reply  = client.call("run", handle, "id -u")
      reply[0].should == 0
      uid = File.read(reply[1]).chomp.to_i
      pool = Warden::Container::UidPool.acquire(quota_config[:uidpool][:name],
                                                quota_config[:uidpool][:count])
      uid.should == pool.acquire
    end

    it 'should fail creating containers if no users are available' do
      handle = client.call("create")
      expect do
        client.call("create")
      end.to raise_error(/no uid available/)
    end

    it 'should succeed creating containers when the pool refills after being empty' do
      handle = client.call("create")
      handle.should match(/^[0-9a-f]{8}$/i)
      expect do
        client.call("create")
      end.to raise_error(/no uid available/)
      reply = client.call("destroy", handle)
      reply.should == "ok"
      handle = client.call("create")
      handle.should match(/^[0-9a-f]{8}$/i)
    end

    it 'should allow the disk quota to be changed' do
      handle = client.call("create")
      client.call("limit", handle, "disk", 12345).should == "ok"
      client.call("limit", handle, "disk").should == 12345
    end

    it 'should set the block quota to 0 on creation' do
      handle = client.call("create")
      client.call("limit", handle, "disk", 12345).should == "ok"
      client.call("limit", handle, "disk").should == 12345
      client.call("destroy", handle)
      handle = client.call("create")
      client.call("limit", handle, "disk").should == 0
    end

    it 'should raise an error if > 1 argument is supplied when setting the disk quota' do
      handle = client.call("create")
      expect do
        client.call("limit", handle, "disk", 1234, 5678)
      end.to raise_error(/invalid number of arguments/i)
    end

    it 'should destroy containers that exceed their quotas' do
      handle = client.call("create")
      # Quota limits are in number of 1k blocks
      one_mb = 2048
      client.call("limit", handle, "disk", one_mb)
      client.call("limit", handle, "disk").should == one_mb
      res = client.call("run", handle, "dd if=/dev/zero of=/tmp/test bs=4MB count=1")
      res[0].should == 1
      File.read(res[2]).should match(/quota exceeded/)

      # Give the quota monitor a chance to run
      sleep(1)

      expect do
        client.call("run", handle, "ls")
      end.to raise_error(/unknown handle/)
    end
  end

  describe "ip filtering", :netfilter => true do

    include_context :server_lxc

    before(:each) do
      @handle = client.call("create")
    end

    it "should deny traffic to denied networks" do
      # make sure the host can reach an ip in the denied range
      `ping -q -w 1 -c 1 4.2.2.2`.should match(/\b1 received\b/i)

      reply = client.call("run", @handle, "ping -q -W 1 -c 1 4.2.2.2")
      reply[0].should == 1
      File.read(reply[1]).should match(/\b0 received\b/i)
    end

    it "should allow traffic after explicitly allowing its destination" do
      # make sure the host can reach an ip in the denied range
      `ping -q -w 1 -c 1 4.2.2.2`.should match(/\b1 received\b/i)

      reply = client.call("net", @handle, "out", "4.2.2.2")
      reply.should == "ok"

      reply = client.call("run", @handle, "ping -q -W 1 -c 1 4.2.2.2")
      reply[0].should == 0
      File.read(reply[1]).should match(/\b1 received\b/i)
    end

    it "should allow traffic to allowed networks" do
      reply = client.call("run", @handle, "ping -q -W 1 -c 1 4.2.2.3")
      reply[0].should == 0
      File.read(reply[1]).should match(/\b1 received\b/i)
    end

    it "should allow other traffic" do
      reply = client.call("run", @handle, "ping -q -W 1 -c 1 8.8.8.8")
      reply[0].should == 0
      File.read(reply[1]).should match(/\b1 received\b/i)
    end
  end
end
