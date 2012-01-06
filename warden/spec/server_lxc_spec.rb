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

describe "server implementing LXC", :needs_root => true do
  it_behaves_like "a warden server", Warden::Container::LXC

  describe 'should allow setting memory limits' do
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

    before :each do
      @handle = client.create
    end

    it 'raises an error if the user supplies an invalid limit' do
      expect do
        client.limit(@handle, "mem", "abcdefg")
      end.to raise_error(/Invalid limit/)
    end

    it 'sets "memory.limit_in_bytes" in the correct cgroup' do
      client.limit(@handle, "mem").should == 0
      hund_mb = 100 * 1024 * 1024
      client.limit(@handle, "mem", hund_mb).should == "ok"
      client.limit(@handle, "mem").should == hund_mb
      raw_lim = File.read(File.join("/dev/cgroup/", "instance-#{@handle}", "memory.limit_in_bytes"))
      raw_lim.to_i.should == hund_mb
    end

    it 'stops containers in which an oom event occurs' do
      one_mb = 1024 * 1024
      usage = File.read(File.join("/dev/cgroup/", "instance-#{@handle}", "memory.usage_in_bytes"))
      mem_limit = usage.to_i + 2 * one_mb
      client.limit(@handle, "mem", mem_limit)
      # Allocate 20MB, this should OOM and cause the container to be torn down
      cmd = 'perl -e \'for ($i = 0; $i < 20; $i++ ) { $foo .= "A" x (1024 * 1024); }\''
      res = client.run(@handle, cmd)
      res[0].should be_nil

      info = client.info(@handle)
      info["state"].should == "stopped"

      expect do
        client.run(@handle, "ls")
      end.to raise_error(/state/)
    end

    it 'should set the "oom" event for containers in which an oom event occurs' do
      one_mb = 1024 * 1024
      usage = File.read(File.join("/dev/cgroup/", "instance-#{@handle}", "memory.usage_in_bytes"))
      mem_limit = usage.to_i + 2 * one_mb
      client.limit(@handle, "mem", mem_limit)
      # Allocate 20MB, this should OOM and cause the container to be torn down
      cmd = 'perl -e \'for ($i = 0; $i < 20; $i++ ) { $foo .= "A" x (1024 * 1024); }\''
      res = client.run(@handle, cmd)

      info = client.info(@handle)
      info["events"].include?("oom").should be_true
    end
  end

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

    before :each do
      @handle = client.create
    end

    it 'allocates a user per container' do
      reply  = client.run(@handle, "id -u")
      reply[0].should == 0
      uid = File.read(reply[1]).chomp.to_i
      pool = Warden::Container::UidPool.acquire(quota_config[:uidpool][:name],
                                                quota_config[:uidpool][:count])
      uid.should == pool.acquire
    end

    it 'should fail creating containers if no users are available' do
      expect do
        client.create
      end.to raise_error(/no uid available/)
    end

    it 'should succeed creating containers when the pool refills after being empty' do
      expect do
        client.create
      end.to raise_error(/no uid available/)
      reply = client.destroy(@handle)
      reply.should == "ok"
      handle = client.create
      handle.should match(/^[0-9a-f]{8}$/i)
    end

    it 'should allow the disk quota to be changed' do
      client.limit(@handle, "disk", 12345).should == "ok"
      client.limit(@handle, "disk").should == 12345
    end

    it 'should set the block quota to 0 on creation' do
      client.limit(@handle, "disk", 12345).should == "ok"
      client.limit(@handle, "disk").should == 12345
      client.destroy(@handle)
      handle = client.create
      client.limit(handle, "disk").should == 0
    end

    it 'should raise an error if > 1 argument is supplied when setting the disk quota' do
      expect do
        client.limit(@handle, "disk", 1234, 5678)
      end.to raise_error(/invalid number of arguments/i)
    end

    it 'should stop containers that exceed their quotas' do
      # Quota limits are in number of 1k blocks
      one_mb = 2048
      client.limit(@handle, "disk", one_mb)
      client.limit(@handle, "disk").should == one_mb
      res = client.run(@handle, "dd if=/dev/zero of=/tmp/test bs=4MB count=1")
      res[0].should == 1
      File.read(res[2]).should match(/quota exceeded/)

      # Give the quota monitor a chance to run
      sleep(0.5)

      expect do
        client.run(@handle, "ls")
      end.to raise_error(/state/)
    end

    it 'should set the "quota_exceeded" event for containers that exceed their disk quotas' do
      # Quota limits are in number of 1k blocks
      one_mb = 2048
      client.limit(@handle, "disk", one_mb)
      client.limit(@handle, "disk").should == one_mb
      res = client.run(@handle, "dd if=/dev/zero of=/tmp/test bs=4MB count=1")

      # Give the quota monitor a chance to run
      sleep(0.5)

      info = client.info(@handle)
      info["events"].include?("quota_exceeded").should be_true
    end

    it 'should return "disk_usage_B" as an entry in "stats" return from "info"' do
      info = client.info(@handle)
      info['stats']['disk_usage_B'].should > 0
    end
  end

  describe "ip filtering", :netfilter => true do

    include_context :server_lxc

    before(:each) do
      @handle = client.create
    end

    it "should deny traffic to denied networks" do
      # make sure the host can reach an ip in the denied range
      `ping -q -w 1 -c 1 4.2.2.2`.should match(/\b1 received\b/i)

      reply = client.run(@handle, "ping -q -W 1 -c 1 4.2.2.2")
      reply[0].should == 1
      File.read(reply[1]).should match(/\b0 received\b/i)
    end

    it "should allow traffic after explicitly allowing its destination" do
      # make sure the host can reach an ip in the denied range
      `ping -q -w 1 -c 1 4.2.2.2`.should match(/\b1 received\b/i)

      reply = client.net(@handle, "out", "4.2.2.2")
      reply.should == "ok"

      reply = client.run(@handle, "ping -q -W 1 -c 1 4.2.2.2")
      reply[0].should == 0
      File.read(reply[1]).should match(/\b1 received\b/i)
    end

    it "should allow traffic to allowed networks" do
      reply = client.run(@handle, "ping -q -W 1 -c 1 4.2.2.3")
      reply[0].should == 0
      File.read(reply[1]).should match(/\b1 received\b/i)
    end

    it "should allow other traffic" do
      reply = client.run(@handle, "ping -q -W 1 -c 1 8.8.8.8")
      reply[0].should == 0
      File.read(reply[1]).should match(/\b1 received\b/i)
    end
  end

  describe "cgroup" do

    include_context :server_lxc

    it 'should return "mem_usage_B" as an entry in "stats" returned from "info"' do
      handle = client.create
      info = client.info(handle)
      info["stats"]["mem_usage_B"].should > 0
    end
  end
end
