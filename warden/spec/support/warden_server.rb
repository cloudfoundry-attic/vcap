require "warden/server"
require "warden/container/lxc"

require "spec_helper"

shared_context :warden_server do

  let(:unix_domain_path) {
    File.expand_path("../../../tmp/warden.sock", __FILE__)
  }

  let(:container_root) {
    File.expand_path("../../../root", __FILE__)
  }

  before :each do
    FileUtils.rm_f(unix_domain_path)

    @pid = fork do
      Process.setsid
      Signal.trap("TERM") { exit }

      Warden::Server.setup \
        :server => {
          :unix_domain_path => unix_domain_path,
          :container_root => container_root,
          :container_klass => container_klass,
          :container_grace_time => 1 },
        :quota => quota_config,
        :logger => {
          :level => :debug,
          :file => File.expand_path("../../../tmp/warden.log", __FILE__) }

      colored_test_name = "\033[37;1m%s\033[0m" % example.metadata[:full_description]
      Warden::Logger.logger.info colored_test_name

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
    `kill -9 -#{@pid}`
    Process.waitpid(@pid)

    # Destroy all artifacts
    Dir[File.join(container_root, "*", ".instance-*")].each do |path|
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
