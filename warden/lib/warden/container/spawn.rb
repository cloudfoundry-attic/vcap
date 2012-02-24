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

        def stdout
          @child.out
        end

        def stderr
          @child.err
        end

        def status
          @child.status
        end

        def runtime
          @child.runtime
        end

        def success?
          @child.success?
        end

        def exit_status
          @child.status.exitstatus
        end

        def initialize(*args)
          @env, @argv, @options = extract_process_spawn_arguments(*args)

          @child = Child.new(env, *(argv + [options]))

          @child.callback do
            set_deferred_success
          end

          @child.errback do |err|
            if err == MaximumOutputExceeded
              err = WardenError.new("command exceeded maximum output")
            elsif err == TimeoutExceeded
              err = WardenError.new("command exceeded maximum runtime")
            else
              err = WardenError.new("unexpected error: #{err.inspect}")
            end

            set_deferred_failure(err)
          end
        end

        # Helper to inject log message
        def set_deferred_success
          if !success?
            warn "exited with #{exit_status}: #{argv.inspect}"
            warn "stdout: #{stdout}"
            warn "stderr: #{stderr}"
          else
            debug "exited successfully: #{argv.inspect}"
          end

          super
        end

        # Helper to inject log message
        def set_deferred_failure(err)
          error "error running #{argv.inspect}: #{err.message}"
          warn "stdout (maybe incomplete): #{stdout}"
          warn "stderr (maybe incomplete): #{stderr}"
          super
        end

        def yield
          f = Fiber.current

          callback do
            if success?
              f.resume(:ok, stdout)
            else
              f.resume(:err, WardenError.new("command exited with failure"))
            end
          end

          errback do |err|
            f.resume(:err, err)
          end

          status, result = Fiber.yield

          raise result if status == :err

          result
        end
      end
    end
  end
end
