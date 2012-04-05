require 'eventmachine'
require 'yajl'
require 'tmpdir'

require 'em/warden/client'

class MockWardenServer
  class Error < StandardError
  end

  class ClientConnection < ::EM::Connection
    include EM::Protocols::LineText2

    class << self
      attr_accessor :handler
    end

    def receive_line(line)
      method, args = Yajl::Parser.parse(line)
      begin
        result = self.class.handler.send(method, *args)
        send_data(encode(result))
      rescue MockWardenServer::Error => e
        send_data(encode(e))
      end
    end

    private

    def encode(payload)
      raw = nil
      if payload.kind_of?(StandardError)
        raw = {'payload' => payload.to_s, 'type' => 'error'}
      else
        raw = {'payload' => payload}
      end

      Yajl::Encoder.encode(raw) + "\n"
    end
  end

  attr_accessor :handler_class
  attr_reader :socket_path

  def initialize(handler=nil)
    @handler_class = Class.new(ClientConnection) { self.handler = handler }
    @server_sig    = nil
    @tmpdir        = Dir.mktmpdir
    @socket_path   = File.join(@tmpdir, "warden.sock")
  end

  def start
    @server_sig = ::EM.start_unix_domain_server(@socket_path, @handler_class)
  end

  def create_connection
    EM.connect_unix_domain(@socket_path, EM::Warden::Client::Connection)
  end

  def create_fiber_aware_client
    EM::Warden::FiberAwareClient.new(@socket_path)
  end

  def stop
    ::EM.stop_server(@server_sig)
    @server_sig = nil
  end
end

def create_mock_handler(method, opts={})
  handler = mock()
  mock_cont = handler.should_receive(method)

  if opts[:args]
    mock_cont = mock_cont.with(opts[:args])
  end

  if result = opts[:result]
    if result.kind_of?(StandardError)
      mock_cont.and_raise(result)
    else
      mock_cont.and_return(result)
    end
  end

  handler
end
