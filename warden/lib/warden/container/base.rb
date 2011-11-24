require "warden/logger"
require "warden/errors"
require "warden/container/script_handler"

require "eventmachine"
require "em/posix/spawn"
require "set"

module Warden

  module Container

    class Base

      include ::EM::POSIX::Spawn
      include EventEmitter
      include Logger

      class << self

        # Stores a map of handles to their respective container objects. Only
        # live containers are reachable through this map. Containers are only
        # added when they are succesfully started, and are immediately removed
        # when they are being destroyed.
        def registry
          @registry ||= {}
        end

        # This needs to be set by some setup routine. Container logic expects
        # this attribute to hold an instance of Warden::Pool::NetworkPool.
        attr_accessor :network_pool

        # Override #new to make sure that acquired resources are released when
        # one of the pooled resourced can not be required. Acquiring the
        # necessary resources must be atomic to prevent leakage.
        def new(conn)
          network = network_pool.acquire
          unless network
            raise WardenError.new("could not acquire network")
          end

          instance = allocate
          instance.instance_eval {
            initialize
            register_connection(conn)

            # Assign acquired resources only after connection has been registered
            @network = network
          }

          instance

        rescue
          network_pool.release(network) if network
          raise
        end

        # Called before the server starts.
        def setup
          # noop
        end

        # Generates process-wide unique job IDs
        def generate_job_id
          @job_id ||= 0
          @job_id += 1
        end
      end

      attr_reader :connections
      attr_reader :jobs

      def initialize
        @connections = ::Set.new
        @jobs = {}
        @created = false
        @destroyed = false

        on(:after_create) {
          # Clients should be able to look this container up
          self.class.registry[handle] = self
        }

        on(:before_destroy) {
          # Clients should no longer be able to look this container up
          self.class.registry.delete(handle)
        }

        on(:after_destroy) {
          # Release network address only if the container has successfully been
          # destroyed. If not, the network address will "leak" and cannot be
          # reused until this process is restarted. We should probably add
          # extra logic to destroy a container in a failure scenario.
          ::EM.add_timer(5) {
            Server.network_pool.release(network)
          }
        }
      end

      def handle
        @network.to_hex
      end

      def gateway_ip
        @network + 1
      end

      def container_ip
        @network + 2
      end

      def register_connection(conn)
        if @destroy_timer
          ::EM.cancel_timer(@destroy_timer)
          @destroy_timer = nil
        end

        if connections.add?(conn)
          conn.on(:close) {
            connections.delete(conn)

            # Destroy container after grace period
            if connections.size == 0
              @destroy_timer =
                ::EM.add_timer(Server.container_grace_time) {
                  f = Fiber.new { destroy }
                  f.resume
                }
            end
          }
        end
      end

      def root_path
        File.join(Server.container_root, self.class.name.split("::").last.downcase)
      end

      def container_path
        File.join(root_path, ".instance-#{handle}")
      end

      def create
        if @created
          raise WardenError.new("container is already created")
        end

        @created = true

        emit(:before_create)
        do_create
        emit(:after_create)

        handle
      end

      def do_create
        raise WardenError.new("not implemented")
      end

      def destroy
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        @destroyed = true

        emit(:before_destroy)
        do_destroy
        emit(:after_destroy)

        "ok"
      end

      def do_destroy
        raise WardenError.new("not implemented")
      end

      def spawn(script)
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        job = create_job(script)
        jobs[job.job_id.to_s] = job

        # Return job id to caller
        job.job_id
      end

      def link(job_id)
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        job = jobs[job_id.to_s]
        unless job
          raise WardenError.new("no such job")
        end

        job.yield
      end

      def run(script)
        link(spawn(script))
      end

      protected

      def sh(*args)
        env, argv, options =  extract_process_spawn_arguments(*args)
        options = { :timeout => 5.0, :max => 1024 * 1024 }.merge(options)
        p = Child.new(env, *(argv + [options]))

        f = Fiber.current
        p.callback { f.resume(:ok) }
        p.errback { |err| f.resume(:err, err) }

        status, err = Fiber.yield
        if status == :err
          message = case err
                    when MaximumOutputExceeded
                      "command exceeded maximum output"
                    when TimeoutExceeded
                      "command exceeded maximum runtime"
                    else
                      "unknown error"
                    end
          raise WardenError.new(message)
        end

      rescue WardenError
        error "error running: #{command.inspect}"
        raise
      end

      class Job

        attr_reader :container
        attr_reader :job_id
        attr_reader :path

        def initialize(container)
          @container = container
          @job_id = container.class.generate_job_id
          @path = File.join("tmp", job_id.to_s)

          @status = nil
          @yielded = []
        end

        def finish
          exit_status_path = File.join(container.container_root_path, path, "exit_status")
          stdout_path = File.join(container.container_root_path, path, "stdout")
          stderr_path = File.join(container.container_root_path, path, "stderr")

          exit_status = File.read(exit_status_path) if File.exist?(exit_status_path)
          exit_status = exit_status.to_i if exit_status && !exit_status.empty?
          stdout_path = nil unless File.exist?(stdout_path)
          stderr_path = nil unless File.exist?(stderr_path)

          @status = [exit_status, stdout_path, stderr_path]
          @yielded.each { |f| f.resume(@status) }
        end

        def yield
          return @status if @status
          @yielded << Fiber.current
          Fiber.yield
        end
      end
    end
  end
end
