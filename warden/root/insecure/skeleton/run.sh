#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

# Determine artifact path for this job
mkdir -p root/tmp
tmp=$(mktemp -d root/tmp/runner-XXXXXX)

# Echo the absolute artifact path so the caller can pick up the artifacts
echo -n ${PWD}/${tmp}

# Store PID of this process while subshell runs
touch pids/${$}
trap "rm -f pids/${$}" EXIT

# Run script with PWD=root
cd root

# Disable errexit so the exit status can be captured and stored
set +o errexit
env -i bash 1> ../${tmp}/stdout 2> ../${tmp}/stderr
echo ${?} > ../${tmp}/exit_status
