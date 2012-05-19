require "warden/server"
require "warden/network"
require "warden/util"

require "spec_helper"

def next_class_c
  $class_c ||= Warden::Network::Address.new("172.16.0.0")

  rv = $class_c
  $class_c = $class_c + 256
  rv
end

shared_context :warden_server do

  let(:unix_domain_path) {
    Warden::Util.path("tmp/warden.sock")
  }

  let(:container_root) {
    File.expand_path("../../../root", __FILE__)
  }

  before :each do
    FileUtils.rm_f(unix_domain_path)

    @container_depot = Dir.mktmpdir

    # Grab new network for every test to avoid resource contention
    start_address = next_class_c

    @pid = fork do
      Process.setsid
      Signal.trap("TERM") { exit }

      Warden::Server.setup \
        "server" => {
          "unix_domain_path" => unix_domain_path,
          "container_root" => container_root,
          "container_klass" => container_klass,
          "container_depot" => @container_depot,
          "container_grace_time" => 1 },
        "network" => {
          "pool_start_address" => start_address,
          "pool_size" => 64,
          "allow_networks" => "4.2.2.3/32",
          "deny_networks" => "4.2.2.0/24" },
        "logging" => {
          "level" => "debug",
          "file" => Warden::Util.path("tmp/warden.log") }

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
    Dir[File.join(container_root, "*", "clear.sh",
                  @container_depot)].each do |clear|
      system(clear)
    end

    FileUtils.rm_rf(@container_depot)
  end
end
