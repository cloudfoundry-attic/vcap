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

# Make loop devices as needed
for i in $(seq 0 1023); do
  file=/dev/loop${i}
  if [ ! -b ${file} ]; then
    mknod -m0660 ${file} b 7 ${i}
    chown root.disk ${file}
  fi
done

# Disable AppArmor if possible
if [ -x /etc/init.d/apparmor ]; then
  /etc/init.d/apparmor teardown
fi
