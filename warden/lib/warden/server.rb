require "warden/network"
require "warden/event_emitter"

require "eventmachine"
require "hiredis/reader"
require "vcap/logging"

require "fileutils"
require "fiber"
require "set"

module Warden

  module Server

    class WardenError < StandardError
    end

    def self.unix_domain_path=(str)
      @unix_domain_path = str
    end

    def self.unix_domain_path
      @unix_domain_path || "/tmp/warden.sock"
    end

    def self.network_start_address=(address)
      @network_start_address = Network::Address.new(address)
    end

    def self.network_start_address
      @network_start_address || Network::Address.new("10.254.0.0")
    end

    def self.network_size=(size)
      @network_size = size
    end

    def self.network_size
      @network_size || 64
    end

    def self.network_pool
      @network_pool ||= NetworkPool.new(network_start_address, network_size)
    end

    def self.run!
      unless IO.readlines("/proc/mounts").find { |e| e =~ %r/ cgroup /i }
        begin
          FileUtils.mkdir_p("/dev/cgroup")
        rescue Errno::EACCES
          raise WardenError.new("unable to create mount point for cgroup vfs")
        end

        unless system("mount -t cgroup none /dev/cgroup")
          raise WardenError.new("unable to mount cgroup vfs")
        end
      end

      ::EM.run {
        server = ::EM.start_unix_domain_server(unix_domain_path, ClientConnection)
      }
    end

    module Logger

      def self.setup_logger(config = {})
        VCAP::Logging.reset
        VCAP::Logging.setup_from_config(config)
        @logger = VCAP::Logging.logger("warden")
      end

      def self.logger
        @logger ||= setup_logger(:level => :info)
      end

      def method_missing(sym, *args)
        if Logger.logger.respond_to?(sym)
          prefix = logger_prefix_from_stack caller(1).first
          fmt = args.shift
          fmt = "%s: %s" % [prefix, fmt] if prefix
          Logger.logger.send(sym, fmt, *args)
        else
          super
        end
      end

      protected

      def logger_prefix_from_stack(str)
        m = str.match(/^(.*):(\d+):in `(.*)'$/i)
        file, line, method = m[1], m[2], m[3]

        file_parts = File.expand_path(file).split("/")
        trimmed_file = file_parts.
          reverse.
          take_while { |e| e != "lib" }.
          reverse.
          join("/")

        class_parts = self.class.name.split("::")
        trimmed_class = class_parts.
          reverse.
          map.
          with_index { |e,i| i == 0 ? e : e[0, 1].upcase }.
          reverse.
          join("::")

        "%s:%s - %s#%s" % [trimmed_file, line, trimmed_class, method]
      end
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
        network = Server.network_pool.acquire
        unless network
          send_error "no available network"
          return
        end

        container = Container.new(network)
        container.register_connection(self)

        begin
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

        container = Container.registry[request[1]]
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

        container = Container.registry[request[1]]
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

    class Container

      include Logger

      def self.registry
        @registry ||= {}
      end

      attr_reader :network
      attr_reader :connections

      def initialize(network)
        @network = network
        @connections = Set.new
      end

      def handle
        network.to_hex
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

      def path
        File.join(ENV["warden_container_root"] || "root", ".instance-#{handle}")
      end

      def rootfs
        File.join(path, "union")
      end

      def env
        {
          "network_gateway_ip" => gateway_ip.to_human,
          "network_container_ip" => container_ip.to_human,
          "network_netmask" => Server.network_pool.netmask.to_human
        }
      end

      def env_command
        "env #{env.map { |k, v| "#{k}=#{v}" }.join(" ")}"
      end

      def register_connection(connection)
        if @connections.add?(connection)
          connection.on(:close) {
            @connections.delete(connection)
            destroy if @connections.size == 0
          }
        end
      end

      def create
        if @created
          raise WardenError.new("container is already created")
        end

        @created = true

        # Create container
        command = "#{env_command} root/create.sh #{handle}"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not create container" }
        debug "container created"

        # Start container
        command = File.join(path, "start.sh")
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not start container" }
        debug "container started"

        # Any client should now be able to look this container up
        register
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

        # Stop container
        command = File.join(path, "stop.sh")
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not stop container" }
        debug "container stopped"

        # Destroy container
        command = "rm -rf #{path}"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not destroy container" }
        debug "container destroyed"

        # Release network address only if the container has successfully been
        # destroyed. If not, the network address will "leak" and cannot be
        # reused until this process is restarted. We should probably add extra
        # logic to destroy a container in a failure scenario.
        ::EM.add_timer(5) {
          Server.network_pool.release(network)
        }
      end

      def run(script)
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        socket_path = File.join(path, "union/tmp/runner.sock")
        unless File.exist?(socket_path)
          error "socket does not exist: #{socket_path}"
        end

        handler = ::EM.connect_unix_domain(socket_path, RemoteScriptHandler, self, script)
        result = handler.yield { error "runner unexpectedly terminated" }
        debug "runner successfully terminated: #{result.inspect}"

        result
      end

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
          set_deferred_success
        end
      end

      class RemoteScriptHandler < ScriptHandler

        attr_reader :container
        attr_reader :command

        def initialize(container, command)
          super()
          @container = container
          @command = command
        end

        def post_init
          send_data command + "\n"

          # Make bash exit without losing the exit status. This can otherwise
          # be done by shutting down the write side of the socket, causing EOF
          # on stdin for the remote. However, EM doesn't do shutdown...
          send_data "exit $?\n"
        end

        def unbind
          if buffer.empty?
            # The wrapper script was terminated before it could return anything.
            # It is likely that the container was destroyed while the script
            # was being executed.
            set_deferred_failure "execution aborted"
          else
            status, path = buffer.chomp.split
            stdout_path = File.expand_path(File.join(container.rootfs, path, "stdout")) if path
            stderr_path = File.expand_path(File.join(container.rootfs, path, "stderr")) if path
            set_deferred_success [status.to_i, stdout_path, stderr_path]
          end
        end
      end
    end

    class NetworkPool

      attr_reader :netmask

      def initialize(start_address, count)
        @netmask = Network::Netmask.new(255, 255, 255, 252)
        @pool = count.times.map { |i|
          start_address + @netmask.size * i
        }
      end

      def acquire
        @pool.shift
      end

      def release(address)
        @pool.push address
      end
    end
  end
end
