#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

for instance in instances/*; do
  [ -f ${instance}/stop.sh ] && ${instance}/stop.sh || true
done

sleep 0.1

for instance in instances/*; do
  rm -rf ${instance}
done
