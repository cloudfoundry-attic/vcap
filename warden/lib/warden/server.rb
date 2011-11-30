require "warden/network"
require "warden/event_emitter"
require "warden/logger"
require "warden/errors"
require "warden/container/lxc"
require "warden/pool/network_pool"

require "eventmachine"
require "hiredis/reader"

require "fileutils"
require "fiber"

module Warden

  module Server

    def self.unix_domain_path
      @unix_domain_path
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

    def self.setup_server(config = nil)
      config ||= {}
      @unix_domain_path = config[:unix_domain_path] || "/tmp/warden.sock"
      @container_root = config[:container_root] || File.expand_path(File.join("..", "..", "..", "root"), __FILE__)
      @container_klass = config[:container_klass] || default_container_klass
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

        case request.first
        when "ping"
          send_status "pong"
        when "create"
          process_create(request)
        when "destroy"
          process_destroy(request)
        when "run"
          process_run(request)
        else
          send_error "unknown command #{request.first.inspect}"
        end
      end

      def process_create(request)
        begin
          container = Server.container_klass.new(self)
          container.create
          send_status container.handle
        rescue WardenError => e
          send_error e.message
        end
      end

      def process_destroy(request)
        if request.size != 2
          send_error "invalid number of arguments"
          return
        end

        container = Server.container_klass.registry[request[1]]
        unless container
          send_error "unknown handle"
          return
        end

        begin
          container.destroy
          send_status "ok"
        rescue WardenError => e
          send_error e.message
        end
      end

      def process_run(request)
        if request.size != 3
          send_error "invalid number of arguments"
          return
        end

        container = Server.container_klass.registry[request[1]]
        unless container
          send_error "unknown handle"
          return
        end

        begin
          result = container.run(request[2])
          send_object result
        rescue WardenError => e
          send_error e.message
        end
      end
    end
  end
end
