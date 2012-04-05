#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

# Kill running processes
for pid in pids/*; do
  if [ -f ${pid} ]; then
    kill -9 $(basename ${pid}) 2> /dev/null || true
    rm -f ${pid}
  fi
done
