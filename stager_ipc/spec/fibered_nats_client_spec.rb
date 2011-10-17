require File.expand_path('../spec_helper', __FILE__)

describe VCAP::Stager::Ipc::FiberedNatsClient do
  describe '#stage' do
    it 'should raise VCAP::Stager::Ipc::RequestTimeoutError if the request times out' do
      nats_conn = mock()
      nats_conn.should_receive(:subscribe).with(any_args())
      nats_conn.should_receive(:unsubscribe).with(any_args())
      nats_conn.should_receive(:publish).with(any_args())
      client = VCAP::Stager::Ipc::FiberedNatsClient.new(nats_conn)
      EM.run do
        Fiber.new do
          expect do
            client.add_task(1, {}, nil, nil, 0.1)
          end.to raise_error(VCAP::Stager::Ipc::RequestTimeoutError)
          EM.stop
        end.resume
      end
    end
  end
end
