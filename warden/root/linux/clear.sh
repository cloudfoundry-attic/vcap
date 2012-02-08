#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

for instance in instances/*; do
  [ -f ${instance}/stop.sh ] && ${instance}/stop.sh
  umount ${instance}/union || true
  rm -rf ${instance}
done
