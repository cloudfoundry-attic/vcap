require "rspec"
require "warden/server"

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

shared_context :warden do

  let(:unix_domain_path) {
    File.expand_path("../../tmp/warden.sock", __FILE__)
  }

  let(:container_root) {
    File.expand_path("../../root", __FILE__)
  }

  before :each do
    FileUtils.rm_f(unix_domain_path)

    @pid = fork do
      Signal.trap("TERM") { exit }

      Warden::Server.setup \
        :server => {
          :container_root => container_root,
          :unix_domain_path => unix_domain_path },
        :logger => {
          :level => :debug,
          :file => File.expand_path("../../tmp/warden.log", __FILE__) }
      Warden::Server.run!
    end

    # Wait for the socket to come up
    until File.exist?(unix_domain_path)
      if Process.waitpid(@pid, Process::WNOHANG)
        STDERR.puts "Warden process exited before socket was up; aborting spec suite."
        exit 1
      end

      sleep 0.01
    end
  end

  after :each do
    `kill -9 #{@pid}`
    Process.waitpid(@pid)

    # Destroy all artifacts
    Dir[File.join(container_root, ".instance-*")].each do |path|
      next if path.match(/-skeleton$/)

      started = File.join(path, "started")
      if File.exist?(started)
        stop_script = File.join(path, "stop.sh")
        system(stop_script) if File.exist?(stop_script)
      end

      # Container should be stopped and destroyed by now...
      system("rm -rf #{path}")
    end
  end
end
