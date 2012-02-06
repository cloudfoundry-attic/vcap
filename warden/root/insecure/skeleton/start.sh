#!/bin/bash

# Change to directory that holds this script
self=$(readlink -f ${0})
cd $(dirname ${self})

# Setup structure
mkdir -p root pids
