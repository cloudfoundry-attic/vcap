#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh
source ./config

mkdir -p /dev/cgroup/instance-${id}
pushd /dev/cgroup/instance-${id} > /dev/null

cat ../cpuset.cpus > cpuset.cpus
cat ../cpuset.mems > cpuset.mems

echo 1 > cgroup.clone_children
echo ${PID} > tasks

popd > /dev/null

echo ${PPID} >> ppid

ip link add name ${network_host_iface} type veth peer name ${network_container_iface}
ip link set ${network_host_iface} netns 1
ip link set ${network_container_iface} netns ${PID}

exit 0
