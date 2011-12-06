#!/usr/bin/env ruby

PATH = File.expand_path("..", __FILE__)
Dir.chdir(PATH)
require "../.lib/global"
require "erb"

config = {
  "id" => "test",
  "network_gateway_ip" => "10.0.0.1",
  "network_container_ip" => "10.0.0.2",
  "network_netmask" => "255.255.255.252",
  "copy_root_password" => "0"
}.merge(ENV)

Dir.chdir("union")

# Hostname
write "etc/hostname", config["id"]
write "etc/hosts", "127.0.0.1 %s localhost" % config["id"]

# Network settings
write "etc/network/interfaces", <<-EOS
auto lo
iface lo inet loopback
auto veth0
iface veth0 inet static
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

# Disable selinux
write "selinux/enforce", 0

# Add vcap user
useradd_cmd = "useradd -mU vcap"
useradd_cmd += " -u #{config['vcap_uid']}" if config['vcap_uid']
chroot ".", useradd_cmd

# Fake upstart triggers
write "etc/init/lxc.conf", <<-EOS
start on startup
script
  /sbin/initctl emit stopped JOB=udevtrigger --no-wait
  /sbin/initctl emit started JOB=udev --no-wait
end script
EOS

# Remove console related upstart scripts
sh "rm -f etc/init/tty[2-9]*"
sh "rm -f etc/init/console-setup.conf"

dev_entries = [
  %w{console tty tty1},
  %w{fd stdin stdout stderr},
  %w{random urandom},
  %w{null zero} ].flatten

# Remove everything from /dev unless whitelisted
Dir["dev/*"].each { |e|
  unless dev_entries.include? File.basename(e)
    sh "rm -rf #{e}"
  end
}

# Add runner script
write "usr/bin/runner", <<-EOS
#!/bin/bash

# Determine artifact path for this job
read job_path
if [ -n "${job_path}" ]; then
tmp=${job_path}
else
tmp=$(mktemp -d)
fi

mkdir -p ${tmp} || exit 1

sudo -u vcap env -i bash 1> ${tmp}/stdout 2> ${tmp}/stderr
echo ${?} > ${tmp}/exit_status
EOS

script "chmod +x usr/bin/runner"

# Add upstart job
write "etc/init/runner.conf", <<-EOS
start on filesystem
respawn
exec socat -ly unix-listen:/tmp/runner.sock,fork exec:/usr/bin/runner,nofork
EOS

Dir.chdir(PATH)

# Write control scripts
write "start.sh", ERB.new(File.read "start.sh.erb").result
write "stop.sh", ERB.new(File.read "stop.sh.erb").result

script <<-EOS
chmod +x start.sh
chmod +x stop.sh
EOS

# Write LXC configuration
write "config", ERB.new(File.read "config.erb").result
