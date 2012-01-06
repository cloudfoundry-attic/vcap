require "socket"
require "yajl"

module Warden

  class Client

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def connected?
      !@sock.nil?
    end

    def connect
      raise "already connected" if connected?
      @sock = ::UNIXSocket.new(path)
    end

    def disconnect
      raise "not connected" unless connected?
      @sock.close rescue nil
      @sock = nil
    end

    def reconnect
      disconnect if connected?
      connect
    end

    def read
      line = @sock.gets
      if line.nil?
        disconnect
        raise ::EOFError
      end

      object = ::Yajl::Parser.parse(line)
      payload = object["payload"]

      # Raise error replies
      if object["type"] == "error"
        raise ::StandardError.new(payload)
      end

      payload
    end

    def write(args)
      json = ::Yajl::Encoder.encode(args, :pretty => false)
      @sock.write(json + "\n")
    end

    def call(args)
      write(args)
      read
    end

    def method_missing(sym, *args, &blk)
      call([sym, *args])
    end
  end
end
