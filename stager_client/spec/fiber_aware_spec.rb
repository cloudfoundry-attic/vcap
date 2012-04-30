require "spec_helper"

describe VCAP::Stager::Client::FiberAware do
  include_context :nats_server

  let(:request) { { "test" => "request" } }

  let(:queue) { "test" }

  describe "#stage" do
    it "should return received responses after yielding the fiber" do
      exp_result = { "test" => "result" }
      recvd_result = nil

      when_nats_connected(nats_server) do |conn|
        handle_request(conn, queue) do |_, reply_to|
          enc_result = Yajl::Encoder.encode(exp_result)
          conn.publish(reply_to, enc_result)
        end

        Fiber.new do
          client = VCAP::Stager::Client::FiberAware.new(conn, queue)

          recvd_result = client.stage(request)

          EM.stop
        end.resume
      end

      recvd_result.should == exp_result
    end

    it "should raise an error when response decoding fails" do
      when_nats_connected(nats_server) do |conn|
        handle_request(conn, queue) do |req, reply_to|
          # Invalid json will cause response parsing to fail
          conn.publish(reply_to, "{{}")
        end

        Fiber.new do
          client = VCAP::Stager::Client::FiberAware.new(conn, queue)

          expect do
            client.stage(request)
          end.to raise_error(Yajl::ParseError)

          EM.stop
        end.resume
      end
    end

    it "should raise an error when the request times out" do
      when_nats_connected(nats_server) do |conn|
        Fiber.new do
          client = VCAP::Stager::Client::FiberAware.new(conn, queue)

          expect do
            client.stage(request, 0.1)
          end.to raise_error(VCAP::Stager::Client::Error, /Timeout/)

          EM.stop
        end
      end
    end
  end
end
