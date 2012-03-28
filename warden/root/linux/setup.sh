#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

cgroup_path=/dev/cgroup
mkdir -p ${cgroup_path}

# Mount if not already mounted
if ! grep -q ${cgroup_path} /proc/mounts; then
  mount -t cgroup -o blkio,devices,memory,cpuacct,cpu,cpuset none ${cgroup_path}
fi

./net.sh setup
