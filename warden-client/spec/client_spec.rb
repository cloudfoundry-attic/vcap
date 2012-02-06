require "spec_helper"
require "support/mock_warden_server"

describe Warden::Client do

  include_context :mock_warden_server

  let(:client) do
    new_client
  end

  it "shouldn't be able to connect without a server" do
    expect do
      client.connect
    end.to raise_error

    client.should_not be_connected
  end

  it "should be able to connect with a server" do
    start_server

    expect do
      client.connect
    end.to_not raise_error

    client.should be_connected
  end

  context "connection management" do

    # This is super-racy: the ivar is updated from the server thread
    def connection_count
      sleep 0.001
      @sessions.size
    end

    before(:each) do
      @sessions = {}
      start_server do |session, _|
        @sessions[session] = 1
      end
    end

    context "when connected" do

      before(:each) do
        client.connect
        client.should be_connected
        connection_count.should == 1
      end

      it "should not allow connecting" do
        expect do
          client.connect
        end.to raise_error

        # This should not affect the connection
        client.should be_connected

        # This should not reconnect
        connection_count.should == 1
      end

      it "should allow disconnecting" do
        client.disconnect
        client.should_not be_connected

        # This should not reconnect
        connection_count.should == 1
      end

      it "should allow reconnecting" do
        client.reconnect
        client.should be_connected

        # This should have reconnected
        connection_count.should == 2
      end
    end

    context "when disconnected" do

      before(:each) do
        connection_count.should == 0
      end

      it "should not allow disconnecting" do
        expect do
          client.disconnect
        end.to raise_error

        # This should not affect the connection
        client.should_not be_connected

        # This should not reconnect
        connection_count.should == 0
      end

      it "should allow connecting" do
        client.connect
        client.should be_connected

        # This should have connected
        connection_count.should == 1
      end

      # While it is semantically impossible to reconnect when the client was
      # never connected to begin with, it IS possible.
      it "should allow reconnecting" do
        client.reconnect
        client.should be_connected

        # This should have connected
        connection_count.should == 1
      end
    end
  end

  context "when connected" do

    before(:each) do
      start_server do |session, args|
        case args.shift
        when "eof"
          session.close
        when "error"
          session.reply(:type => "error", :payload => "error")
        when "echo"
          session.reply(:payload => args)
        end
      end

      client.connect
      client.should be_connected
    end

    it "should raise EOFError on eof" do
      expect do
        client.eof
      end.to raise_error(::EOFError)

      # This should update the connection status
      client.should_not be_connected
    end

    it "should raise StandardError on error payloads" do
      expect do
        client.error
      end.to raise_error(::StandardError)

      # This should not affect the connection
      client.should be_connected
    end

    it "should return decoded payload for non-error replies" do
      reply = client.echo("hello")
      reply.should == ["hello"]
    end
  end
end
