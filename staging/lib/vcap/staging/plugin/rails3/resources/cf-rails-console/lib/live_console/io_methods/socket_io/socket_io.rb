require 'live_console/io_methods/socket_io/connection'

class LiveConsole::IOMethods::SocketIO
  DefaultOpts = {
    :host => '127.0.0.1',
  }.freeze
  RequiredOpts = DefaultOpts.keys + [:port]

  include LiveConsole::IOMethods::IOMethod

  def initialize(opts)
    super opts
    @server = TCPServer.new host, port
  end

  def get_connection
    LiveConsole::IOMethods::SocketIOConnection.new(@server, opts)
  end
end
