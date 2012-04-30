require "fiber"

require "vcap/stager/client/em_aware"

module VCAP
  module Stager
    module Client
    end
  end
end

class VCAP::Stager::Client::FiberAware < VCAP::Stager::Client::EmAware
  # Requests that an application be staged. Blocks the current fiber until
  # the request completes.
  #
  # @see VCAP::Stager::EmClient#stage for a description of the arguments
  #
  # @return [Hash]
  def stage(*args, &blk)
    promise = super

    f = Fiber.current

    promise.on_response { |response| f.resume({ :response => response }) }

    promise.on_error { |e| f.resume({ :error => e }) }

    result = Fiber.yield

    if result[:error]
      raise result[:error]
    else
      result[:response]
    end
  end
end
