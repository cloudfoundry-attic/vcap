# Copyright (c) 2009-2011 VMware, Inc.
require 'eventmachine'
require 'em-http-request'
require 'fiber'

require 'services/api/const'

module VCAP
  module Services
    module Api
    end
  end
end

module VCAP::Services::Api
  class AsyncHttpRequest
    class << self
      def new(url, token, verb, timeout, msg=VCAP::Services::Api::EMPTY_REQUEST)

        req = {
          :head => {
            VCAP::Services::Api::GATEWAY_TOKEN_HEADER => token,
            'Content-Type' => 'application/json',
          },
          :body => msg.encode,
        }
        if timeout
          EM::HttpRequest.new(url, :inactivity_timeout => timeout).send(verb.to_sym, req)
        else
          EM::HttpRequest.new(url).send(verb.to_sym, req)
        end
      end

      def fibered(url, token, verb, timeout, msg=VCAP::Services::Api::EMPTY_REQUEST)
        req = new(url, token, verb, timeout, msg)
        f = Fiber.current
        req.callback { f.resume(req) }
        req.errback  { f.resume(req) }
        Fiber.yield
      end
    end
  end
end
