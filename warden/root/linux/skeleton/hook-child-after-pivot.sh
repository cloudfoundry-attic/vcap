#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh
source ./config

mkdir -p /dev/pts
mount -t devpts -o newinstance,ptmxmode=0666 devpts /dev/pts
ln -s pts/ptmx /dev/ptmx

hostname ${id}
