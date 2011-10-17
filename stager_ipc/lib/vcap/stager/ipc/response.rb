require 'yajl'

require 'vcap/stager/ipc/errors'

module VCAP
  module Stager
    module Ipc
    end
  end
end

class VCAP::Stager::Ipc::Response

  class << self
    def decode(encoded_response)
      begin
        decoded_response = Yajl::Parser.parse(encoded_response)
      rescue => e
        raise VCAP::Stager::Ipc::DecodeError, "Failed decoded response '#{encoded_response}': '#{e}'"
      end

      new(decoded_response['request_id'], decoded_response['inbox'], decoded_response['result'])
    end

    def for_request(req)
      new(req.request_id, req.inbox)
    end
  end

  attr_reader :inbox
  attr_reader :request_id
  attr_accessor :result

  # @param  request  VCAP::Stager::Ipc::Request
  def initialize(request_id, inbox, result=nil)
    @request_id = request_id
    @inbox      = inbox
    @result     = result
  end

  def encode
    h = {
      :request_id => @request_id,
      :result     => @result,
    }

    Yajl::Encoder.encode(h)
  rescue => e
    raise VCAP::Stager::Ipc::EncodeError, "Failed encoding request: #{e}"
  end
end
