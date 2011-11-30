require "warden/network"
require "warden/event_emitter"
require "warden/logger"
require "warden/errors"
require "warden/container/lxc"
require "warden/container/insecure"
require "warden/pool/network_pool"

require "eventmachine"
require "hiredis/reader"

require "fileutils"
require "fiber"

module Warden

  module Server

    def self.default_unix_domain_path
      "/tmp/warden.sock"
    end

    def self.unix_domain_path
      @unix_domain_path
    end

    def self.default_container_root
      File.expand_path(File.join("..", "..", "..", "root"), __FILE__)
    end

    def self.container_root
      @container_root
    end

    # This is hard-coded to LXC; we can be smarter using `uname`, "/etc/issue", etc.
    def self.default_container_klass
      ::Warden::Container::LXC
    end

    def self.container_klass
      @container_klass
    end

    def self.default_container_grace_time
      5 * 60 # 5 minutes
    end

    def self.container_grace_time
      @container_grace_time
    end

    def self.setup_server(config = nil)
      config ||= {}
      @unix_domain_path = config.delete(:unix_domain_path) { default_unix_domain_path }
      @container_root = config.delete(:container_root) { default_container_root  }
      @container_klass = config.delete(:container_klass) { default_container_klass }
      @container_grace_time = config.delete(:container_grace_time) { default_container_grace_time }
    end

    def self.setup_logger(config = nil)
      config ||= {}
      Warden::Logger.setup_logger(config)
    end

    def self.setup_network(config = nil)
      config ||= {}
      network_start_address = Network::Address.new(config[:start_address] || "10.254.0.0")
      network_size = config[:size] || 64
      network_pool = Pool::NetworkPool.new(network_start_address, network_size)
      container_klass.network_pool = network_pool
    end

    def self.setup(config = {})
      setup_server config[:server]
      setup_logger config[:logger]
      setup_network config[:network]
    end

    def self.run!
      container_klass.setup

      ::EM.run {
        FileUtils.rm_f(unix_domain_path)
        server = ::EM.start_unix_domain_server(unix_domain_path, ClientConnection)
      }
    end

    class ClientConnection < ::EM::Connection

      include EventEmitter
      include Logger

      def post_init
        @blocked = false
        @closing = false
      end

      def unbind
        f = Fiber.new { emit(:close) }
        f.resume
      end

      def close
        close_connection_after_writing
        @closing = true
      end

      def closing?
        !! @closing
      end

      def reader
        @reader ||= ::Hiredis::Reader.new
      end

      def send_data(str)
        super
      end

      def send_status(str)
        send_data "+#{str}\r\n"
      end

      def send_error(str)
        send_data "-err #{str}\r\n"
      end

      def send_integer(i)
        send_data ":#{i.to_s}\r\n"
      end

      def send_nil
        send_data "$-1\r\n"
      end

      def send_bulk(str)
        send_data "$#{str.to_s.length}\r\n#{str.to_s}\r\n"
      end

      def send_object(obj)
        case obj
        when Fixnum
          send_integer obj
        when NilClass
          send_nil
        when String
          send_bulk obj
        when Enumerable
          send_data "*#{obj.size}\r\n"
          obj.each { |e| send_object(e) }
        else
          raise "cannot send #{obj.class}"
        end
      end

      def receive_data(data = nil)
        reader.feed(data) if data

        # Don't start new request when old one hasn't finished, or the
        # connection is about to be closed.
        return if @blocked or @closing

        # Reader#gets returns false when no request is available.
        request = reader.gets
        return if request == false

        f = Fiber.new {
          begin
            @blocked = true
            process(request)

          ensure
            @blocked = false

            # Resume processing the input buffer
            ::EM.next_tick { receive_data }
          end
        }

        f.resume
      end

      def process(request)
        unless request.is_a?(Array)
          send_error "invalid request"
          return
        end

        debug request.inspect

        if request.empty?
          return
        end

        begin
          method = "process_#{request.first}"
          if respond_to?(method)
            result = send(method, Request.new(request))
          else
            raise WardenError.new("unknown command #{request.first.inspect}")
          end

          send_object(result)
        rescue WardenError => e
          send_error e.message
        end
      end

      def process_ping(_)
        "pong"
      end

      def process_create(request)
        container = Server.container_klass.new(self)
        container.create
      end

      def process_destroy(request)
        request.require_arguments { |n| n == 2 }
        container = find_container(request[1])
        container.destroy
      end

      def process_spawn(request)
        request.require_arguments { |n| n == 3 }
        container = find_container(request[1])
        container.spawn(request[2])
      end

      def process_link(request)
        request.require_arguments { |n| n == 3 }
        container = find_container(request[1])
        container.link(request[2])
      end

      def process_run(request)
        request.require_arguments { |n| n == 3 }
        container = find_container(request[1])
        container.run(request[2])
      end

      protected

      def find_container(handle)
        Server.container_klass.registry[handle].tap do |container|
          raise WardenError.new("unknown handle") if container.nil?

          # Let the container know that this connection references it
          container.register_connection(self)
        end
      end

      class Request < Array

        def require_arguments
          unless yield(size)
            raise WardenError.new("invalid number of arguments")
          end
        end
      end
    end
  end
end
