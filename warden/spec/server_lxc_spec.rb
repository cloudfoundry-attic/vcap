require "spec_helper"

describe "server implementing LXC" do
  it_behaves_like "a warden server", Warden::Container::LXC

  describe 'when configured with a uid pool', :needs_root => true do
    include_context :warden_server
    include_context :warden_client

    let(:container_klass) {
      Warden::Container::LXC
    }

    let(:client) {
      create_client
    }

    let(:uidpool_config) {
      { :name => 'warden-lxc-uidpool-server-test',
        :count => 1,
      }
    }

    it 'allocates a user per container' do
      handle = client.call("create")
      reply  = client.call("run", handle, "id -u")
      reply[0].should == 0
      uid = File.read(reply[1]).chomp.to_i
      uid.should == @pool.acquire
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
  end

  describe 'when configured with quota support', :needs_root => true, :needs_quota_fs => true do
    include_context :warden_server
    include_context :warden_client

    let(:container_klass) {
      Warden::Container::LXC
    }

    let(:client) {
      create_client
    }

    let(:uidpool_config) {
      { :name => 'warden-lxc-uidpool-server-test',
        :count => 1,
      }
    }

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
  end
end
