require "warden/logger"
require "warden/errors"

require "em/posix/spawn"
require "em/deferrable"
require "fiber"

module Warden

  module Container

    module Spawn

      protected

      def sh(*args)
        options =
          if args[-1].respond_to?(:to_hash)
            args.pop.to_hash
          else
            {}
          end

        options = { :timeout => 5.0, :max => 1024 * 1024 }.merge(options)
        p = DeferredChild.new(*(args + [options]))
        p.yield
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
              # Log last line of stderr. Don't use this as message for the raised
              # error to prevent internal information from leaking to clients.
              error "stderr: #{p.err.split(/\n/).last.inspect}"

              err = WardenError.new("command exited with failure")
              set_deferred_failure(err)
            end

            set_deferred_success
          }

          p.errback { |err|
            message = case err
                      when MaximumOutputExceeded
                        "command exceeded maximum output"
                      when TimeoutExceeded
                        "command exceeded maximum runtime"
                      end

            err = WardenError.new(message)
            set_deferred_failure(err)
          }
        end

        # Helper to inject log message
        def set_deferred_success
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
          callback { f.resume(:ok) }
          errback { |err| f.resume(:err, err) }
          status, err = Fiber.yield
          raise err if status == :err
        end
      end
    end
  end
end
