#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh
source ./config

if [ -f started ]; then
  echo "Container is already running..."
  exit 1
fi

./net.sh setup

env -i unshare -n ../../../../src/clone/clone

ifconfig ${network_host_iface} ${network_host_ip} netmask ${network_netmask}
touch started

function ssh_state() {
  grep "ssh state changed" console.log | cut -d" " -f8
}

start=$(date +%s)
while ! ssh_state | grep -q "running"; do
  if [ $(($(date +%s) - ${start})) -gt 5 ]; then
    echo "Timeout waiting for SSH to come up..."
    exit 1
  fi

  sleep 0.02
done

# Setup persistent connections into the container
#
# -v: Verbose mode.
# -M: Places the ssh client into "master" mode for connection sharing.
# -f: Requests ssh to go to background just before command execution.
# -N: Do not execute a remote command.
# -F: Specifies an alternative per-user configuration file.
#
ssh -v -M -f -N -F ssh/ssh_config root@${id} \
  1> ssh/control-root@${network_container_ip}.stdout \
  2> ssh/control-root@${network_container_ip}.stderr
ssh -v -M -f -N -F ssh/ssh_config vcap@${id} \
  1> ssh/control-vcap@${network_container_ip}.stdout \
  2> ssh/control-vcap@${network_container_ip}.stderr
