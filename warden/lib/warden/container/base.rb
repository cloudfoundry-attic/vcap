require "warden/logger"
require "warden/errors"
require "warden/container/spawn"
require "warden/container/script_handler"

require "eventmachine"
require "set"

module Warden

  module Container

    class Base

      include EventEmitter
      include Spawn
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
        def setup(config={})
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
            self.class.network_pool.release(network)
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

      def net_inbound_port
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        _net_inbound_port
      end

      def get_limit(limit_name)
        getter = "get_limit_#{limit_name}"
        if respond_to?(getter)
          self.send(getter)
        else
          raise WardenError.new("Unknown limit #{limit_name}")
        end
      end

      def set_limit(limit_name, args)
        setter = "set_limit_#{limit_name}"
        if respond_to?(setter)
          self.send(setter, args)
        else
          raise WardenError.new("Unknown limit #{limit_name}")
        end
      end

      protected

      class Job

        include Logger

        attr_reader :container
        attr_reader :job_id

        def initialize(container)
          @container = container
          @job_id = container.class.generate_job_id

          @status = nil
          @yielded = []
        end

        def finish(path = nil)
          path ||= "/idontexist"
          exit_status_path = File.join(path, "exit_status")
          stdout_path = File.join(path, "stdout")
          stderr_path = File.join(path, "stderr")

          exit_status = File.read(exit_status_path) if File.exist?(exit_status_path)
          exit_status = exit_status.to_i if exit_status && !exit_status.empty?
          stdout_path = nil unless File.exist?(stdout_path)
          stderr_path = nil unless File.exist?(stderr_path)

          status = [exit_status, stdout_path, stderr_path]
          debug "job exit status: #{exit_status}"

          resume(status)
        end

        def yield
          return @status if @status
          @yielded << Fiber.current
          Fiber.yield
        end

        def resume(status)
          @status = status
          @yielded.each { |f| f.resume(@status) }
        end
      end
    end
  end
end
