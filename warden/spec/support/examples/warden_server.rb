require "support/warden_server"
require "support/warden_client"

shared_examples "a warden server" do |container_klass|

  include_context :warden_server
  include_context :warden_client

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
    client.call("ping").should == "pong"
  end

  it "should allow to create a container" do
    handle = client.call("create")
    handle.should match(/^[0-9a-f]{8}$/i)
  end

  it "allows destroying a container" do
    handle = client.call("create")

    reply = client.call("destroy", handle)
    reply.should == "ok"

    # It should raise when container has already been destroyed
    lambda {
      reply = client.call("destroy", handle)
    }.should raise_error(/unknown handle/i)
  end

  describe "running commands inside a container" do

    before(:each) do
      @handle = client.call("create")
    end

    it "should redirect stdout output" do
      reply = client.call("run", @handle, "echo hi")
      reply[0].should == 0
      File.read(reply[1]).should == "hi\n"
      File.read(reply[2]).should == ""
    end

    it "should redirect stderr output" do
      reply = client.call("run", @handle, "echo hi 1>&2")
      reply[0].should == 0
      File.read(reply[1]).should == ""
      File.read(reply[2]).should == "hi\n"
    end

    it "should propagate exit status" do
      reply = client.call("run", @handle, "exit 123")
      reply[0].should == 123
    end

    it "should return an error when the handle is unknown" do
      lambda {
        client.call("run", @handle.next, "whoami")
      }.should raise_error(/unknown handle/i)
    end

    it "should work when the container gets destroyed" do
      client.write(["run", @handle, "sleep 5"])
      client.flush

      # Wait for the command to run
      sleep 0.1

      reply = other_client.call("destroy", @handle)
      reply.should == "ok"

      # Expect an error for the running command
      lambda {
        client.read
      }.should raise_error(/execution aborted/i)
    end
  end
end
