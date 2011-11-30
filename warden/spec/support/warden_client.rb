require "hiredis"

shared_context :warden_client do

  class ClientSpecificallyMadeForSpecs < ::Hiredis::Connection

    attr_reader :path

    def initialize(path)
      super()

      @path = path
      reconnect
    end

    def reconnect
      disconnect if connected?
      connect_unix(path)
    end

    def read
      reply = super
      raise reply if reply.kind_of?(StandardError)
      reply
    end

    def write(*args)
      super(args)
      flush
    end

    def call(*args)
      write(*args)
      read
    end
  end

  def create_client
    ClientSpecificallyMadeForSpecs.new(unix_domain_path)
  end
end
