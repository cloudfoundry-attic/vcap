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
../../../../src/clone/clone

ifconfig ${network_iface_host} ${network_gateway_ip} netmask ${network_netmask}
touch started
