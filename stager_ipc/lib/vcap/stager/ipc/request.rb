require 'yajl'

require 'vcap/stager/ipc/errors'

module VCAP
  module Stager
    module Ipc
    end
  end
end

class VCAP::Stager::Ipc::Request
  class << self
    def get_request_id
      @id_ctr ||= 0
      ret = @id_ctr
      @id_ctr += 1
      ret
    end

    def decode(encoded_request)
      begin
        decoded_request = Yajl::Parser.parse(encoded_request)
      rescue => e
        raise VCAP::Stager::Ipc::DecodeError, "Failed decoded request '#{encoded_request}': '#{e}'"
      end

      new(decoded_request['method'],
          decoded_request['args'],
          :inbox      => decoded_request['inbox'],
          :request_id => decoded_request['request_id'])
    end
  end

  attr_reader :method
  attr_reader :inbox
  attr_reader :args
  attr_reader :request_id

  # @param method  Symbol  The method being invoked
  # @param args    Hash
  # @param opts    Hash    :inbox       => where the result should be sent
  #                        :request_id  => unique id for the request, one will be generated
  #                                        if none provided
  def initialize(method, args, opts={})
    @method     = method.to_sym
    @args       = args
    @request_id = opts[:request_id] || self.class.get_request_id
    @inbox      = opts[:inbox]      || "vcap.stager.request.#{@request_id}"
  end

  def encode
    h = {
      :method => @method,
      :inbox  => @inbox,
      :args   => @args,
      :request_id => @request_id,
    }

    Yajl::Encoder.encode(h)
  rescue => e
    raise VCAP::Stager::Ipc::EncodeError, "Failed encoding request: #{e}"
  end
end
