require "yajl"

require "vcap/stager/client/errors"

module VCAP
  module Stager
    module Client
    end
  end
end

class VCAP::Stager::Client::EmAware
  class Promise
    def initialize
      @success_cb = nil
      @error_cb = nil
    end

    # Sets the block to be called when we hear a response for the request.
    #
    # @param [Block]  Block to be called when the response arrives. Must take
    #                 a response as the single argument.
    # @return [nil]
    def on_response(&blk)
      @success_cb = blk

      nil
    end

    # Sets the block to be called when an error occurs while attempting to
    # fulfill the request. Currently, this is only when response deserialization
    # fails.
    #
    # @param [Block]  Block to be called on error. Must take the error that
    #                 occurred as the single argument.
    #
    # @return [nil]
    def on_error(&blk)
      @error_cb = blk

      nil
    end

    def fulfill(result)
      @success_cb.call(result) if @success_cb

      nil
    end

    def fail(error)
      @error_cb.call(error) if @error_cb

      nil
    end
  end

  # @param [NATS]    Nats connection to use as transport
  # @param [String]  Queue to publish the request to
  def initialize(nats, queue)
    @nats  = nats
    @queue = queue
  end

  # Requests that an application be staged
  #
  # @param [Hash] request_details
  # @param [Integer] How long to wait for a response
  #
  # @return [VCAP::Stager::EMClient::Promise]
  def stage(request_details, timeout_secs = 120)
    request_details_json = Yajl::Encoder.encode(request_details)

    promise = VCAP::Stager::Client::EmAware::Promise.new

    sid = @nats.request(@queue, request_details_json) do |result|
      begin
        decoded_result = Yajl::Parser.parse(result)
      rescue => e
        promise.fail(e)
        next
      end

      # Needs to be outside the begin-rescue-end block to ensure that #fulfill
      # doesn't cause #fail to be called.
      promise.fulfill(decoded_result)
    end

    @nats.timeout(sid, timeout_secs) do
      err = VCAP::Stager::Client::Error.new("Timed out after #{timeout_secs}s.")
      promise.fail(err)
    end

    promise
  end
end
