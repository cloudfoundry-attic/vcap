require "rspec"
require "tempfile"

Dir["./spec/support/**/*.rb"].each { |f| require f }

def em(options = {})
  raise "no block given" unless block_given?
  timeout = options[:timeout] ||= 1.0

  ::EM.run {
    quantum = 0.005
    ::EM.set_quantum(quantum * 1000) # Lowest possible timer resolution
    ::EM.set_heartbeat_interval(quantum) # Timeout connections asap
    ::EM.add_timer(timeout) { raise "timeout" }
    yield
  }
end

def done
  raise "reactor not running" if !::EM.reactor_running?

  ::EM.next_tick {
    # Assert something to show a spec-pass
    :done.should == :done
    ::EM.stop_event_loop
  }
end

RSpec.configure do |config|
  config.before(:each) do
    # Run every logging statement, but discard output
    Warden::Server.setup \
      :logger => {
        :level => :debug2,
        :file => "/dev/null" }
  end
end
