require 'rubygems'
require 'bundler/setup'

require 'nats/client'

# Short circuit the reconnect time here by just firing disconnect logic
module NATS
  def unbind
    process_disconnect
  end
end
