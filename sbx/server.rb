require 'rubygems'
require 'sinatra/async'
require 'eventmachine'
require 'thin'
require File.expand_path('../lxc_manager.rb', __FILE__)

class LXC_Server < Sinatra::Base
  register Sinatra::Async

  set :raise_errors, false
  set :show_exceptions, false

  apost '/' do
    config = request.body.string
    config = nil if config == ""
    @manager.create config do |handle|
      #TODO - If the server crashes, the periodic timers die.
      # Need to make sure they are included when the server
      # comes back up.
      EM.add_periodic_timer(60) do
        #TODO - Need to establish a protocol for Agent and Server to send/receive heartbeats
      end
      body handle
    end
  end

  # Delete the sandbox for the application
  adelete '/:handle' do |handle|
    @manager.destroy handle do |resp|
      body resp
    end
  end

  error do
    "There was an error: #{env['sinatra.error'].message}"
  end

  def initialize
    super
    @manager = LXC_Manager.new
  end

end
