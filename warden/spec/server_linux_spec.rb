require "spec_helper"

shared_context :server_linux do

  include_context :warden_server
  include_context :warden_client

  let(:container_klass) {
    Warden::Container::Linux
  }

  let (:client) {
    create_client
  }
end

describe "server implementing Linux containers", :platform => "linux", :needs_root => true do
  it_behaves_like "a warden server", Warden::Container::Linux

  describe 'should allow setting memory limits' do
    include_context :warden_server
    include_context :warden_client

    let(:container_klass) {
      Warden::Container::Linux
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
      _ = client.run(@handle, cmd)

      # Wait a bit for the warden to be notified of the OOM
      sleep 0.01

      info = client.info(@handle)
      info["state"].should == "stopped"
      info["events"].should include("oom")

      expect do
        client.run(@handle, "ls")
      end.to raise_error(/state/)
    end
  end

  describe "ip filtering", :netfilter => true do

    include_context :server_linux

    before(:each) do
      @handle = client.create
    end

    it "should deny traffic to denied networks" do
      # make sure the host can reach an ip in the denied range
      `ping -q -w 1 -c 1 4.2.2.2`.should match(/\b1 received\b/i)

      reply = client.run(@handle, "ping -q -W 1 -c 1 4.2.2.2")
      reply[0].should == 1
      reply[1].should match(/\b0 received\b/i)
    end

    it "should allow traffic after explicitly allowing its destination" do
      # make sure the host can reach an ip in the denied range
      `ping -q -w 1 -c 1 4.2.2.2`.should match(/\b1 received\b/i)

      reply = client.net(@handle, "out", "4.2.2.2")
      reply.should == "ok"

      reply = client.run(@handle, "ping -q -W 1 -c 1 4.2.2.2")
      reply[0].should == 0
      reply[1].should match(/\b1 received\b/i)
    end

    it "should allow traffic to allowed networks" do
      reply = client.run(@handle, "ping -q -W 1 -c 1 4.2.2.3")
      reply[0].should == 0
      reply[1].should match(/\b1 received\b/i)
    end

    it "should allow other traffic" do
      reply = client.run(@handle, "ping -q -W 1 -c 1 8.8.8.8")
      reply[0].should == 0
      reply[1].should match(/\b1 received\b/i)
    end
  end

  describe "cgroup" do

    include_context :server_linux

    it 'should return "mem_usage_B" as an entry in "stats" returned from "info"' do
      handle = client.create
      info = client.info(handle)
      info["stats"]["mem_usage_B"].should > 0
    end
  end

  describe "bind mounts" do

    include_context :server_linux

    before :each do
      @tmpdir = Dir.mktmpdir
      @test_path = File.join(@tmpdir, "test")
      @test_basename = "test"
      @test_contents = "testing123"
      File.open(@test_path, "w+") {|f| f.write(@test_contents) }
      FileUtils.chmod_R(0777, @tmpdir)
      @bind_mount_path = "/tmp/bind_mounted"
      @config = {
        "bind_mounts" => [
          [@tmpdir, @bind_mount_path, {}]
        ]
      }
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it "should raise an error if an invalid mode is supplied" do
      @config["bind_mounts"][0][2]["mode"] = "invalid"
      expect do
        handle = client.create(@config)
      end.to raise_error(/Invalid mode/)
    end

    it "should support bind mounting paths from the host into the container" do
      handle = client.create(@config)

      # Make sure we can read a file that already exists
      result = client.run(handle, "cat #{@bind_mount_path}/#{@test_basename}")
      result[0].should == 0
      result[1].should == @test_contents

      # Make sure we can create/write a file
      new_contents = "test"
      new_path = "#{@bind_mount_path}/newfile"
      result = client.run(handle, "echo -n #{new_contents} > #{new_path}")
      result[0].should == 0
      result = client.run(handle, "cat #{new_path}")
      result[0].should == 0
      result[1].should == new_contents
    end

    it "should support bind mounting paths with different permissions" do
      @config["bind_mounts"][0][2]["mode"] = "ro"
      handle = client.create(@config)

      result = client.run(handle, "touch #{@bind_mount_path}/test")
      result[0].should == 1
      result[2].should match(/Read-only file system/)
    end
  end
end
