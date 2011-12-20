require "support/warden_server"
require "support/warden_client"

shared_examples "a warden server" do |container_klass|

  include_context :warden_server
  include_context :warden_client

  let(:quota_config) {
    nil
  }

  let(:container_klass) {
    container_klass
  }

  let(:client) {
    create_client
  }

  let(:other_client) {
    create_client
  }

  it "should be reachable" do
    client.ping.should == "pong"
  end

  it "should allow to create a container" do
    handle = client.create
    handle.should match(/^[0-9a-f]{8}$/i)
  end

  it "allows destroying a container" do
    handle = client.create

    reply = client.destroy(handle)
    reply.should == "ok"

    # It should raise when container has already been destroyed
    lambda {
      reply = client.destroy(handle)
    }.should raise_error(/unknown handle/i)
  end

  describe "running commands inside a container" do

    before(:each) do
      @handle = client.create
    end

    it "should redirect stdout output" do
      reply = client.run(@handle, "echo hi")
      reply[0].should == 0
      File.read(reply[1]).should == "hi\n"
      File.read(reply[2]).should == ""
    end

    it "should redirect stderr output" do
      reply = client.run(@handle, "echo hi 1>&2")
      reply[0].should == 0
      File.read(reply[1]).should == ""
      File.read(reply[2]).should == "hi\n"
    end

    it "should propagate exit status" do
      reply = client.run(@handle, "exit 123")
      reply[0].should == 123
    end

    it "should return an error when the handle is unknown" do
      lambda {
        client.run(@handle.next, "whoami")
      }.should raise_error(/unknown handle/i)
    end

    it "should work when the container gets destroyed" do
      client.write(["run", @handle, "sleep 5"])

      # Wait for the command to run
      sleep 0.1

      reply = other_client.destroy(@handle)
      reply.should == "ok"

      # The command should not have exited cleanly
      reply = client.read
      reply[0].should_not == 0
    end
  end

  describe "re-attaching running jobs" do

    context "on the same connection" do

      it "works when the client links to its unfinished job" do
        handle = client.create
        job = client.spawn(handle, "sleep 0.05")
        sleep 0.00
        result = client.link(handle, job)

        # Only test exit status
        result[0].should == 0
      end

      it "works when the client links to its finished job" do
        handle = client.create
        job = client.spawn(handle, "sleep 0.00")
        sleep 0.05
        result = client.link(handle, job)

        # Only test exit status
        result[0].should == 0
      end
    end

    context "on different connections" do

      let(:c1) { create_client }
      let(:c2) { create_client }

      it "works when both c1 and c2 link to c1's unfinished job" do
        handle = c1.create
        job = c1.spawn(handle, "sleep 0.05")

        c1.write(["link", handle, job])
        c2.write(["link", handle, job])

        r1 = c1.read
        r2 = c2.read
        r1.should == r2
      end

      it "works when both c1 and c2 link to c1's finished job" do
        handle = c1.create
        job = c1.spawn(handle, "sleep 0.00")

        sleep 0.05
        c1.write(["link", handle, job])
        c2.write(["link", handle, job])

        r1 = c1.read
        r2 = c2.read
        r1.should == r2
      end

      it "works when c2 links to c1's job after c1 disconnected" do
        handle = c1.create
        job = c1.spawn(handle, "sleep 0.05")
        c1.disconnect

        # Link on different connection
        result = c2.link(handle, job)

        # Only test exit status
        result[0].should == 0
      end
    end
  end

  context "container cleanup" do

    before(:each) do
      @handle = client.create

      # Test that the container is running
      result = client.run(@handle, "echo")
      result[0].should == 0
    end

    it "destroys unreferenced containers after some time" do
      # Disconnect the client
      client.disconnect

      # Let the grace time pass
      sleep 1.1

      # Test that the container can no longer be referenced
      lambda {
        client.reconnect
        result = client.run(@handle, "echo")
      }.should raise_error(/unknown handle/)
    end

    it "doesn't destroy containers when referenced by another client" do
      # Disconnect the client
      client.disconnect
      client.reconnect

      # Wait some time, but don't run out of grace time
      sleep 0.1

      # Test that the container can still be referenced
      lambda {
        result = client.run(@handle, "echo")
        result[0].should == 0
      }.should_not raise_error

      # Wait for the original grace time to run out
      sleep 1.0

      # The new connection should have taken over ownership of this container
      # and canceled the original grace time
      lambda {
        result = client.run(@handle, "echo")
        result[0].should == 0
      }.should_not raise_error
    end
  end


  describe "container limits" do
    before :each do
      @handle = client.create
    end

    it 'should raise an error attempting to get an unknown limit' do
      expect do
        client.limit(@handle, 'does_not_exist')
      end.to raise_error(/unknown limit/i)
    end

    it 'should raise an error attempting to set an unknown limit' do
      expect do
        client.limit(@handle, 'does_not_exist', 12345)
      end.to raise_error(/unknown limit/i)
    end
  end

  describe "container info" do
    before :each do
      @handle = client.create
    end

    it 'should respond to the "info" command' do
      result = client.info(@handle)
      result.kind_of?(Hash).should be_true
    end

    it 'should return the container state as part of "info"' do
      info = client.info(@handle)
      info["state"].should == "active"
    end
  end

  describe "when stopped" do
    before :each do
      @handle = client.create
    end

    it "should kill all running processes" do
      job = client.spawn(@handle, "sleep 5")
      # Give the insecure container a chance to write out the pid
      sleep 0.2
      client.stop(@handle).should == "ok"
      result = client.link(@handle, job)
      # Command should not have exited cleanly
      result[0].should be_nil
    end

    it "should prevent new commands from being run or spawned" do
      client.stop(@handle).should == "ok"
      expect do
        client.run(@handle, "echo test")
      end.to raise_error(/state/)
      expect do
        client.spawn(@handle, "echo test")
      end.to raise_error(/state/)
    end

    it "should allow info to be queried" do
      client.stop(@handle).should == "ok"
      info = client.info(@handle)
      info.kind_of?(Hash).should be_true
    end

    it "should allow the container to be destroyed" do
      client.stop(@handle).should == "ok"
      client.destroy(@handle).should == "ok"
      expect do
        client.info(@handle)
      end.to raise_error(/unknown handle/)
    end
  end

end
