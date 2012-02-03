#!/bin/bash

# Change to directory that holds this script
self=$(readlink -f ${0})
cd $(dirname ${self})

# Kill running scripts
./killprocs.sh

# Don't propagate exit status from loop body
exit 0
