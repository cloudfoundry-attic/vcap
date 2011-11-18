require "warden/event_emitter"

require "eventmachine"
require "hiredis/reader"

module Warden

  class Client

    include EventEmitter

    def initialize(path)
      @deferrables = []
      @connection = ::EM.connect_unix_domain(path, ServerConnection)

      @connection.on(:reply) { |reply|
        deferrable = @deferrables.shift
        next unless deferrable

        if RuntimeError === reply
          deferrable.set_deferred_failure(reply)
        else
          deferrable.set_deferred_success(reply)
        end
      }

      @connection.on(:connected) {
        emit(:connected)
      }

      @connection.on(:closed) {
        emit(:closed)
      }
    end

    def create
      send_command ["create"]
    end

    def destroy(handle)
      send_command ["destroy", handle]
    end

    def run(handle, script)
      send_command ["run", handle, script]
    end

    def call(*args)
      send_command args
    end

    protected

    def send_command(args)
      @connection.send_command(args)
      @deferrables << ::EM::DefaultDeferrable.new
      @deferrables.last
    end

    class ServerConnection < ::EM::Connection

      include EventEmitter

      def post_init
        @reader = ::Hiredis::Reader.new
      end

      def connection_completed
        emit(:connected)
      end

      def receive_data(data)
        @reader.feed(data) if data
        while (reply = @reader.gets) != false
          emit(:reply, reply)
        end
      end

      def unbind
        emit(:closed)
      end

      def send_command(args)
        send_data build_command(args)
      end

      protected

      COMMAND_DELIMITER = "\r\n"

      def build_command(args)
        command = []
        command << "*#{args.size}"

        args.each do |arg|
          arg = arg.to_s
          command << "$#{string_size arg}"
          command << arg
        end

        # Trailing delimiter
        command << ""
        command.join(COMMAND_DELIMITER)
      end

      if "".respond_to?(:bytesize)
        def string_size(string)
          string.to_s.bytesize
        end
      else
        def string_size(string)
          string.to_s.size
        end
      end
    end
  end
end
