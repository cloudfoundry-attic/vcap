#!/bin/bash

# Change to directory that holds this script
self=$(readlink -f ${0})
cd $(dirname ${self})

# Kill running scripts
for pid in pids/*; do
  [ -f $pid ] && kill -9 $(basename ${pid})
done

# Don't propagate exit status from loop body
exit 0
