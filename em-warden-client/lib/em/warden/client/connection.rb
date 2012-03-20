require 'eventmachine'
require 'yajl'

require 'em/warden/client/error'
require 'em/warden/client/event_emitter'

module EventMachine
  module Warden
    module Client
    end
  end
end

class EventMachine::Warden::Client::Connection < ::EM::Connection
  include EM::Warden::Client::EventEmitter
  include EM::Protocols::LineText2

  class CommandResult
    def initialize(value)
      @value = value
    end

    def get
      if @value.kind_of?(StandardError)
        raise @value
      else
        @value
      end
    end
  end

  def post_init
    @request_queue   = []
    @current_request = nil
    @connected       = false
  end

  def connected?
    @connected
  end

  def connection_completed
    @connected = true
    emit(:connected)
  end

  def call(method, *args, &blk)
    @request_queue << {:data => [method, *args], :callback => blk}
    process_queue
  end

  def method_missing(method, *args, &blk)
    call(method, *args, &blk)
  end

  def receive_line(line)
    obj = Yajl::Parser.parse(line)

    unless @current_request
      # Should never happen
      raise "Logic error! Received reply without a corresponding request"
    end

    if @current_request[:callback]
      payload =
        if obj['type'] == 'error'
          EventMachine::Warden::Client::Error.new(obj['payload'])
        else
          obj['payload']
        end
      result = CommandResult.new(payload)
      @current_request[:callback].call(result)
    end

    @current_request = nil

    process_queue
  end

  def unbind
    @connected = false
    emit(:disconnected)
  end

  def process_queue
    return if @current_request || @request_queue.empty?

    @current_request = @request_queue.shift

    send_data(Yajl::Encoder.encode(@current_request[:data]) + "\n")
  end
end
