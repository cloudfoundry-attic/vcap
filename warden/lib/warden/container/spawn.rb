require "warden/logger"
require "warden/errors"

require "em/posix/spawn"
require "em/deferrable"
require "fiber"

module Warden

  module Container

    module Spawn

      def self.included(base)
        base.extend(self)
      end

      def sh(*args)
        options =
          if args[-1].respond_to?(:to_hash)
            args.pop.to_hash
          else
            {}
          end

        skip_raise = options.delete(:raise) == false
        options = { :timeout => 5.0, :max => 1024 * 1024 }.merge(options)

        p = DeferredChild.new(*(args + [options]))
        p.yield

      rescue WardenError => err
        if skip_raise
          nil
        else
          raise
        end
      end

      # Thin utility class around EM::POSIX::Spawn::Child. It instruments the
      # logger in case of error conditions. Also, it considers any non-zero
      # exit status as an error. In this case, it tries to log as much
      # information as possible and subsequently triggers the failure callback.

      class DeferredChild

        include ::EM::POSIX::Spawn
        include ::EM::Deferrable
        include Logger

        attr_reader :env
        attr_reader :argv
        attr_reader :options

        def initialize(*args)
          @env, @argv, @options = extract_process_spawn_arguments(*args)

          p = Child.new(env, *(argv + [options]))

          p.callback {
            unless p.success?
              # Log stderr. Don't use this as message for the raised error to
              # prevent internal information from leaking to clients.
              error "stderr: #{p.err.inspect}"

              err = WardenError.new("command exited with failure")
              set_deferred_failure(err)
            else
              set_deferred_success(p.out)
            end
          }

          p.errback { |err|
            if err == MaximumOutputExceeded
              err = WardenError.new("command exceeded maximum output")
            elsif err == TimeoutExceeded
              err = WardenError.new("command exceeded maximum runtime")
            else
              err = WardenError.new("unexpected error: #{err.inspect}")
            end

            set_deferred_failure(err)
          }
        end

        # Helper to inject log message
        def set_deferred_success(result)
          debug "successfully ran #{argv.inspect}"
          super
        end

        # Helper to inject log message
        def set_deferred_failure(err)
          error "error running #{argv.inspect}: #{err.message}"
          super
        end

        def yield
          f = Fiber.current
          callback { |result| f.resume(:ok, result) }
          errback { |err| f.resume(:err, err) }
          status, result = Fiber.yield
          raise result if status == :err
          result
        end
      end
    end
  end
end
