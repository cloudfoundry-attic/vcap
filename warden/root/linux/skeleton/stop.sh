#!/bin/bash

set -o nounset
set -o errexit
cd $(dirname $(readlink -f ${0}))

source ./common.sh
source ./config

if [ ! -f started ]; then
  echo "Container is not running..."
  exit 1
fi

./killprocs.sh
umount_union
rm -f started
