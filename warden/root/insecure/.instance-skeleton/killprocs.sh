#!/bin/bash

for pid in pids/*; do
  [ -f $pid ] && kill -9 $(basename ${pid})
done
