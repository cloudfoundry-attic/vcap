#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

# Store PID of this process while subshell runs
touch pids/${$}
trap "rm -f pids/${$}" EXIT

# Run script with PWD=root
cd root

# Replace process with bash interpreting stdin
exec env -i bash
