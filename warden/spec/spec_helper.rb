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
  if Process.uid != 0
    config.filter_run_excluding :needs_root => true
  end

  unless (Process.uid == 0) && ENV['WARDEN_TEST_QUOTA_FS'] && ENV['WARDEN_TEST_REPORT_QUOTA_PATH']
    config.filter_run_excluding :needs_quota_config => true
  end

  config.before(:each) do
    config = {
      # Run every logging statement, but discard output
      :logger => {
        :level => :debug2,
        :file  => '/dev/null',
      },
    }
    Warden::Server.setup(config)
  end
end
