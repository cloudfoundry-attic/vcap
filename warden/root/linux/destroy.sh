#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob

if [ $# -ne 1  ]; then
  echo "Usage: ${0} <instance_path>"
  exit 1
fi

target=${1}

if [ -d "${target}" ]; then
  if [ -f "${target}/destroy.sh" ]; then
    ${target}/destroy.sh
  fi

  rm -rf ${target}
fi
