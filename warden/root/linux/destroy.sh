#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

if [ -z "${1}" ]; then
  echo "Usage: ${0} <name>"
  exit 1
fi

target="instances/${1}"

if [ -d "${target}" ]; then
  if [ -f "${target}/destroy.sh" ]; then
    ${target}/destroy.sh
  fi

  rm -rf ${target}
fi
