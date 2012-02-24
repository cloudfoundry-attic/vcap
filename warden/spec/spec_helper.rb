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

def em_fibered(options = {}, &blk)
  em(options) do
    Fiber.new do
      blk.call
    end.resume
  end
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

  # Exclude specs for other platforms
  config.exclusion_filter = {
    :platform => lambda { |platform|
      RUBY_PLATFORM !~ /#{platform}/i },
  }

  if Process.uid != 0
    config.filter_run_excluding :needs_root => true
  end

  config.before(:each) do
    config = {
      # Run every logging statement, but discard output
      :logging => {
        :level => :debug2,
        :file  => '/dev/null',
      },
    }
    Warden::Server.setup(config)
  end
end
