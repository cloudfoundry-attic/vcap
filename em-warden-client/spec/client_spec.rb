require 'spec_helper'
require 'support/mock_warden_server'

describe EventMachine::Warden::Client do
  describe "events" do
    it 'should emit the "connected" event upon connection completion' do
      server = MockWardenServer.new(nil)
      received_connected = false
      em do
        server.start
        conn = server.create_connection
        conn.on(:connected) { received_connected = true }
        EM.stop
      end
      received_connected.should be_true
    end

    it 'should emit the "disconnected" event upon connection termination' do
      server = MockWardenServer.new(nil)
      received_disconnected =false
      em do
        server.start
        conn = server.create_connection
        conn.on(:disconnected) { received_disconnected = true }
        EM.stop
      end
      received_disconnected.should be_true
    end
  end

  describe "when connected" do
    it 'should return non-error payloads' do
      args = {"foo" => "bar"}
      expected_result = ["test_result"]
      handler = create_mock_handler(:test, :args => args, :result => expected_result)
      server = MockWardenServer.new(handler)
      result = nil
      em do
        server.start
        conn = server.create_connection
        conn.test(args) do |res|
          result = res.get
          EM.stop
        end
      end
      result.should == expected_result
    end

    it 'should raise error payloads' do
      handler = create_mock_handler(:test, :result => MockWardenServer::Error.new("test error"))
      server = MockWardenServer.new(handler)
      em do
        server.start
        conn = server.create_connection
        conn.test do |res|
          expect do
            res.get
          end.to raise_error(/test error/)
          EM.stop
        end
      end
    end

    it 'should queue subsequent requests' do
      handler = create_mock_handler(:test1)
      handler.should_receive(:test2)
      server = MockWardenServer.new(handler)
      em do
        server.start
        conn = server.create_connection
        conn.test1
        conn.test2 {|res| EM.stop }
      end
    end
  end
end
