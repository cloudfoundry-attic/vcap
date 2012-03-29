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

env -i unshare -n ../../../../src/clone/clone

ifconfig ${network_iface_host} ${network_gateway_ip} netmask ${network_netmask}
touch started

function ssh_state() {
  grep "ssh state changed" console.log | cut -d" " -f8
}

start=$(date +%s)
while ! ssh_state | grep -q "spawned"; do
  if [ $(($(date +%s) - ${start})) -gt 5 ]; then
    echo "Timeout waiting for SSH to come up..."
    exit 1
  fi

  sleep 0.1
done

# Setup persistent connections into the container
ssh -o ControlMaster=yes -N -F ssh/ssh_config root@${id} &
ssh -o ControlMaster=yes -N -F ssh/ssh_config vcap@${id} &
