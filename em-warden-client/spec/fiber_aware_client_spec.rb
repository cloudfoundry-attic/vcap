require 'spec_helper'
require 'support/mock_warden_server'

describe EventMachine::Warden::FiberAwareClient do
  describe '#connected' do
    it 'should yield the calling fiber until connected' do
      server = MockWardenServer.new(nil)
      em do
        server.start
        client = server.create_fiber_aware_client
        Fiber.new do
          client.connect
          client.connected?.should be_true
          EM.stop
        end.resume
      end
    end
  end

  describe '#disconnect' do
    it 'should yield the calling fiber until disconnected' do
      server = MockWardenServer.new(nil)
      em do
        server.start
        client = server.create_fiber_aware_client
        Fiber.new do
          client.connect
          client.connected?.should be_true
          client.disconnect
          client.connected?.should be_false
          EM.stop
        end.resume
      end
    end
  end

  describe '#method_missing' do
    it 'should return non-error payloads' do
      args = {"foo" => "bar"}
      expected_result = ["test_result"]
      handler = create_mock_handler(:test, :args => args, :result => expected_result)
      server = MockWardenServer.new(handler)
      result = nil
      em do
        server.start
        client = server.create_fiber_aware_client
        Fiber.new do
          client.connect
          result = client.test(args)
          EM.stop
        end.resume
      end
      result.should == expected_result
    end

    it 'should raise error payloads' do
      handler = create_mock_handler(:test, :result => MockWardenServer::Error.new("test error"))
      server = MockWardenServer.new(handler)
      em do
        server.start
        client = server.create_fiber_aware_client
        Fiber.new do
          client.connect
          expect do
            client.test
          end.to raise_error(/test error/)
          EM.stop
        end.resume
      end
    end
  end
end
