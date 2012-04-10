#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

# Wait for the kernel to release resources
while [ 1 ]; do
  if [ -f ppid ]; then
    kill -9 $(cat ppid) 2> /dev/null || true
    rm -f ppid
  fi

  [ $(losetup -j fs | wc -l) -eq 0 ] && exit 0
  sleep 0.1
done

exit 1
