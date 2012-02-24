#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

if [ -f ppid ]; then
  kill -9 $(cat ppid) 2> /dev/null || true
  rm -f ppid
fi

# Wait for the kernel to release resources
for i in $(seq 20); do
  [ $(losetup -j fs | wc -l) -eq 0 ] && break
  sleep 0.1
done
