#!/usr/bin/env ruby

require File.expand_path("../../.lib/global", $0)
require "erb"

mount_union

# Defaults for debugging the setup script
defaults = {
  "id" => "test",
  "network_gateway_ip" => "10.0.0.1",
  "network_container_ip" => "10.0.0.2",
  "network_netmask" => "255.255.255.252",
  "copy_root_password" => "0",
}

# Override defaults from environment
config = defaults.merge(ENV)

# These variables are always synthesized from the instance id
config["network_iface_host"] = "veth-%s-0" % config["id"]
config["network_iface_container"] = "veth-%s-1" % config["id"]

Dir.chdir File.expand_path("..", $0)

# Write control scripts
write "start.sh", ERB.new(File.read "start.sh.erb").result
write "pre-exec.sh", ERB.new(File.read "pre-exec.sh.erb").result
write "stop.sh", ERB.new(File.read "stop.sh.erb").result
write "killprocs.sh", ERB.new(File.read "killprocs.sh.erb").result

script <<-EOS
chmod +x start.sh
chmod +x pre-exec.sh
chmod +x stop.sh
chmod +x killprocs.sh
EOS

Dir.chdir "union"

# Hostname
write "etc/hostname", config["id"]
write "etc/hosts", "127.0.0.1 %s localhost" % config["id"]

# Network settings
write "etc/network/interfaces", <<-EOS
auto lo
iface lo inet loopback
auto #{config["network_iface_container"]}
iface #{config["network_iface_container"]} inet static
  gateway #{config["network_gateway_ip"]}
  address #{config["network_container_ip"]}
  netmask #{config["network_netmask"]}
EOS

# Inherit nameserver configuration from host
FileUtils.cp "/etc/resolv.conf", "etc"

# Copy root password
if config["copy_root_password"].to_i != 0
  def shadow(file)
    IO.readlines(file).map { |e| e.split(":") }
  end

  def find_root(lines)
    lines.find { |e| e[0] == "root" } || fail("not found")
  end

  host_shadow = shadow("/etc/shadow")
  container_shadow = shadow("etc/shadow")
  find_root(container_shadow)[1] = find_root(host_shadow)[1]
  write "etc/shadow", container_shadow.map { |e| e.join(":") }.join
end

# Add vcap user
useradd_cmd = "useradd -mU vcap"
useradd_cmd += " -u #{config["vcap_uid"]}" if config["vcap_uid"]
chroot ".", useradd_cmd

# Fake upstart triggers
write "etc/init/lxc.conf", <<-EOS
start on startup
script
  /sbin/initctl emit stopped JOB=udevtrigger --no-wait
  /sbin/initctl emit started JOB=udev --no-wait
end script
EOS

# Add runner
sh "cp ../../../../src/runner bin/"

# Add upstart job
write "etc/init/runner.conf", <<-EOS
start on filesystem and net-device-up IFACE=#{config["network_iface_container"]}
respawn
env ARTIFACT_PATH=/tmp
env RUN_AS_UID=#{chroot ".", "id -u vcap"}
exec runner listen /tmp/runner.sock
EOS
