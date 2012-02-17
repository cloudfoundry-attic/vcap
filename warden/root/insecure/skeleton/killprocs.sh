#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

for pid in pids/*; do
  [ -f $pid ] && kill -9 $(basename ${pid}) 2> /dev/null || true
done
