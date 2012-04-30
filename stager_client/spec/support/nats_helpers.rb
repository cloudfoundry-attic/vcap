require "eventmachine"
require "nats/client"
require "rspec"
require "socket"

class ForkedNatsServer

  attr_reader :pid, :host, :port

  def initialize(opts = {})
    @show_output = opts[:show_output] || false
    @timeout = opts[:wait_timeout] || 5
    @pid = nil
    @port = nil
    @host = "127.0.0.1"
  end

  def start
    return if @pid

    @port = reserve_port

    opts = (@show_output ? {} : { :err => :close, :out => :close })

    @pid = Process.spawn("nats-server -a 127.0.0.1 -p #{port}", opts)

    wait_for_server(@port, @timeout)

    @port
  end

  def stop
    return unless @pid

    Process.kill('KILL', @pid)

    Process.waitpid(@pid)

    @pid = nil

    nil
  end

  private

  def reserve_port
    socket = TCPServer.new("0.0.0.0", 0)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    Socket.do_not_reverse_lookup = true
    port = socket.addr[1]
    socket.close
    return port
  end

  def wait_for_server(port, timeout)
    socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    addr = Socket.sockaddr_in(port, "127.0.0.1")
    connected = false
    max_tries = 5
    sleep_base = 0.1

    0.upto(max_tries) do |try_num|
      begin
        socket.connect(addr)
        connected = true
        break
      rescue Errno::ECONNREFUSED
        # Total of 6.3 secs. Progression is 0.1, 0.2, 0.4, 0.8, ...
        sleep(sleep_base * (2 ** try_num))
      end
    end

    connected
  end
end


shared_context :nats_server do
  let(:nats_server) do
    ForkedNatsServer.new(
      :show_output => ENV["VCAP_TEST_LOG"] == "true")
  end

  before(:all) { nats_server.start }
  after(:all) { nats_server.stop }
end

def when_nats_connected(nats_server, timeout = 5, &blk)
  host, port = nats_server.host, nats_server.port
  EM.run do
    NATS.connect(:uri => "nats://#{host}:#{port}") do |conn|
      blk.call(conn)
    end

    EM.add_timer(timeout) { EM.stop }
  end
end


def handle_request(conn, subj, &blk)
  conn.subscribe(subj) do |msg, reply_to|
    decoded_message = Yajl::Parser.parse(msg)

    blk.call(decoded_message, reply_to)
  end

  # Ensure that our subscribe has been processed. Side effect!
  conn.flush
end
