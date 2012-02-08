#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

# Kill running scripts
./killprocs.sh

# Don't propagate exit status from loop body
exit 0
