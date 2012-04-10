require 'eventmachine'
require 'fiber'

require 'em/warden/client/connection'
require 'em/warden/client/error'

module EventMachine
  module Warden
  end
end

class EventMachine::Warden::FiberAwareClient

  attr_reader :socket_path

  def initialize(socket_path)
    @socket_path = socket_path
    @connection  = nil
  end

  def connect
    return if @connection
    @connection = EM.connect_unix_domain(@socket_path, EM::Warden::Client::Connection)
    f = Fiber.current
    @connection.on(:connected) { f.resume }
    Fiber.yield
  end

  def connected?
    @connection.connected?
  end

  def method_missing(method, *args, &blk)
    raise EventMachine::Warden::Client::Error.new("Not connected") unless @connection.connected?

    f = Fiber.current
    @connection.call(method, *args) {|res| f.resume(res) }
    result = Fiber.yield

    result.get
  end

  def disconnect(close_after_writing=true)
    @connection.close_connection(close_after_writing)
    f = Fiber.current
    @connection.on(:disconnected) { f.resume }
    Fiber.yield
  end
end
