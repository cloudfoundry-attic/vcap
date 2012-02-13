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

mount_union

export ROOT_PATH=union
export ASSET_PATH=$(pwd)
../../../../src/clone/clone

ifconfig ${network_iface_host} ${network_gateway_ip} netmask ${network_netmask}
touch started

# Wait for the runner socket to come up
start=$(date +%s)
while [ ! -S union/tmp/runner.sock ]; do
  if [ $(($(date +%s) - ${start})) -gt 5 ]; then
    echo "Timeout waiting for runner socket to come up..."
    exit 1
  fi

  sleep 0.1
done
