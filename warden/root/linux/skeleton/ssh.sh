#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh
source ./config

ssh \
  -o "StrictHostKeyChecking yes" \
  -o "UserKnownHostsFile ssh/known_hosts" \
  -i ssh/root_key \
  root@${network_container_ip} \
  $@
