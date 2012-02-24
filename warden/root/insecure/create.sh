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
mkdir -p instances

if [ -d ${target} ]; then
  echo "\"${target}\" already exists, aborting..."
  exit 1
fi

cp -r skeleton "${target}"
unshare -m "${target}"/setup.sh
echo ${target}
