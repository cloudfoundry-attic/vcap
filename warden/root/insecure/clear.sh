#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

if [ $# -ne 1 ]; then
  echo "Usage: ${0} <instances_path>"
  exit 1
fi

instances_path=${1}

for instance in instances_path/*; do
  [ -f ${instance}/stop.sh ] && ${instance}/stop.sh || true
done

sleep 0.1

for instance in instances_path/*; do
  rm -rf ${instance}
done
