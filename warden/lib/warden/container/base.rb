require "warden/logger"
require "warden/errors"

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
      end

      def self.new(conn)
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

      attr_reader :connections

      def initialize
        @connections = ::Set.new
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
    end
  end
end
