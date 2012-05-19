#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh
source ./config

rootfs_path=${rootfs_path:-../../base/rootfs}

setup_fs ${rootfs_path}
