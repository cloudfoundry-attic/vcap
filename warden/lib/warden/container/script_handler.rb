require "warden/logger"
require "warden/errors"

require "eventmachine"
require "time"
require "fiber"

module Warden

  module Container

    class ScriptHandler < ::EM::Connection

      include ::EM::Deferrable
      include Logger

      attr_reader :buffer

      def initialize()
        @buffer = ""
        @start = Time.now
      end

      def yield
        f = Fiber.current
        callback { |result| f.resume(:success, result) }
        errback { |result| f.resume(:failure, result) }

        status, result = Fiber.yield
        debug "invocation took: %.3fs" % (Time.now - @start)

        if status == :failure
          yield if block_given?
          raise WardenError.new((result || "unknown error").to_s)
        end

        result
      end

      def receive_data(data)
        @buffer << data
      end

      def unbind
        exit_status = get_status.exitstatus
        debug "exit status: #{exit_status}"
        debug "stdout: #{@buffer.inspect}"

        if exit_status != 0
          set_deferred_failure
        else
          set_deferred_success
        end
      end
    end
  end
end
