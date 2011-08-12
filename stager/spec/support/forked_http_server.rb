require 'rack/handler/webrick'
require 'socket'

module VCAP
  module Stager
    module Spec
    end
  end
end

class VCAP::Stager::Spec::ForkedHttpServer
  attr_reader :port

  def initialize(handler, port, log_dir='/tmp')
    @handler = handler
    @started = false
    @port    = port
    @pid     = nil
    @log_dir = log_dir
  end

  def start
    return if @started
    @pid = fork do
      trap('TERM') { Rack::Handler::WEBrick.shutdown }

      log_fn = File.join(@log_dir, "http_server.#{Process.pid}.out")
      logger = WEBrick::Log.new(log_fn)

      Rack::Handler::WEBrick.run(@handler,
                                 :Host   => '127.0.0.1',
                                 :Port   => @port,
                                 :Logger => logger,
                                 :AccessLog => [[logger, WEBrick::AccessLog::COMBINED_LOG_FORMAT]])
      exit!
    end
    @started = true
    self
  end

  def stop
    return unless @started
    Process.kill('TERM', @pid)
    Process.waitpid(@pid)
    @started = false
  end

  def wait_ready(tries=5)
    ret = false
    tries.downto(1) do
      if ready?
        ret = true
        break
      else
        sleep(0.1)
      end
    end
    ret
  end

  def ready?
    begin
      s = TCPSocket.new('127.0.0.1', @port)
      s.close
      true
    rescue => e
      false
    end
  end
end
