#!/bin/bash

self=$(readlink -f ${0})
cd $(dirname ${self})

# Prevents globs from expanding to themselves if nothing matches
shopt -s nullglob

for pid in pids/*; do
  [ -f $pid ] && kill -9 $(basename ${pid})
done
