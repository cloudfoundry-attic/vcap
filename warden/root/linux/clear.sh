#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob

if [ $# -ne 1 ]; then
  echo "Usage: ${0} <instances_path>"
  exit 1
fi

instances_path=${1}

cd $(dirname "${0}")

for instance in ${instances_path}/*; do
  echo "Destroying ${instance}"
  ./destroy.sh ${instance} &
done

wait
