require 'rspec'
require 'em/warden/client'

def em(options = {})
  raise "no block given" unless block_given?
  timeout = options[:timeout] ||= 1.0

  ::EM.run do
    quantum = 0.005
    ::EM.set_quantum(quantum * 1000) # Lowest possible timer resolution
    ::EM.set_heartbeat_interval(quantum) # Timeout connections asap
    ::EM.add_timer(timeout) { raise "timeout" }
    yield
  end
end
