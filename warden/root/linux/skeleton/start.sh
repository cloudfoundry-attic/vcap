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

export ROOT_PATH=union
export ASSET_PATH=$(pwd)
unshare -n ../../../../src/clone/clone

ifconfig ${network_iface_host} ${network_gateway_ip} netmask ${network_netmask}
touch started

function ssh_running() {
  cat console.log | grep "ssh state changed" | tail -n1 | cut -d' ' -f8 | grep running > /dev/null
}

start=$(date +%s)
while ! ssh_running; do
  if [ $(($(date +%s) - ${start})) -gt 5 ]; then
    echo "Timeout waiting for SSH to come up..."
    exit 1
  fi

  sleep 0.1
done
