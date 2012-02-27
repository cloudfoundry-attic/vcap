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

echo ${PPID} >> ${ASSET_PATH}/ppid

ip link add name ${network_iface_host} type veth peer name ${network_iface_container}
ip link set ${network_iface_host} netns 1
ip link set ${network_iface_container} netns ${PID}

exit 0
