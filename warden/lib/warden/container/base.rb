require "warden/logger"
require "warden/errors"
require "warden/container/script_handler"

require "eventmachine"
require "set"

module Warden

  module Container

    class Base

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
      end

      attr_reader :connections

      def initialize
        @connections = ::Set.new
        @created = false
        @destroyed = false
      end

      def handle
        @network.to_hex
      end

      def register
        self.class.registry[handle] = self
        nil
      end

      def unregister
        self.class.registry.delete(handle)
        nil
      end

      def gateway_ip
        @network + 1
      end

      def container_ip
        @network + 2
      end

      def register_connection(conn)
        if connections.add?(conn)
          conn.on(:close) {
            connections.delete(conn)
            destroy if connections.size == 0
          }
        end
      end

      def root_path
        File.join(Server.container_root, self.class.name.split("::").last.downcase)
      end

      def container_path
        File.join(root_path, ".instance-#{handle}")
      end

      def sh(command)
        handler = ::EM.popen(command, ScriptHandler)
        yield handler if block_given?
        handler.yield # Yields fiber

      rescue WardenError
        error "error running: #{command.inspect}"
        raise
      end

      def create
        if @created
          raise WardenError.new("container is already created")
        end

        @created = true

        do_create

        # Any client should now be able to look this container up
        register
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

        # Clients should no longer be able to look this container up
        unregister

        do_destroy

        # Release network address only if the container has successfully been
        # destroyed. If not, the network address will "leak" and cannot be
        # reused until this process is restarted. We should probably add extra
        # logic to destroy a container in a failure scenario.
        ::EM.add_timer(5) {
          Server.network_pool.release(network)
        }
      end

      def do_destroy
        raise WardenError.new("not implemented")
      end

      def run(script)
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        do_run(script)
      end

      def do_run(script)
        raise WardenError.new("not implemented")
      end
    end
  end
end
