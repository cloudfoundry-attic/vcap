#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh

# Defaults for debugging the setup script
id=${id:-test}
network_gateway_ip=${network_gateway_ip:-10.0.0.1}
network_container_ip=${network_container_ip:-10.0.0.2}
network_netmask=${network_netmask:-255.255.255.252}
copy_root_password=${copy_root_password:-0}

# These variables are always synthesized from the instance id
network_iface_host="veth-${id}-0"
network_iface_container="veth-${id}-1"

# Write configuration
cat > config <<-EOS
id=${id}
network_gateway_ip=${network_gateway_ip}
network_container_ip=${network_container_ip}
network_netmask=${network_netmask}
copy_root_password=${copy_root_password}
network_iface_host=${network_iface_host}
network_iface_container=${network_iface_container}
EOS

setup_fs
trap "teardown_fs" EXIT

write "etc/hostname" <<-EOS
${id}
EOS

write "etc/hosts" <<-EOS
127.0.0.1 ${id} localhost
EOS

write "etc/network/interfaces" <<-EOS
auto lo
iface lo inet loopback
auto ${network_iface_container}
iface ${network_iface_container} inet static
  gateway ${network_gateway_ip}
  address ${network_container_ip}
  netmask ${network_netmask}
EOS

# Inherit nameserver(s)
cp /etc/resolv.conf ${target}/etc/

# Add vcap user
chroot <<-EOS
useradd -mU vcap ${vcap_uid+-u ${vcap_uid}}
EOS

# Figure out the actual user ID
vcap_uid=$(chroot <<< "id -u vcap")

# Fake udev upstart triggers
write "etc/init/fake-udev.conf" <<-EOS
start on startup
script
  /sbin/initctl emit stopped JOB=udevtrigger --no-wait
  /sbin/initctl emit started JOB=udev --no-wait
end script
EOS

# Add runner
cp ../../../../src/runner ${target}/bin/

# Add upstart job
write "etc/init/runner.conf" <<-EOS
start on filesystem and net-device-up IFACE=${network_iface_container}
respawn
env ARTIFACT_PATH=/tmp
env RUN_AS_UID=${vcap_uid}
exec runner listen /tmp/runner.sock
EOS
