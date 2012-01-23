#!/bin/bash

set -o nounset
set -o errexit
cd $(dirname $(readlink -f ${0}))

source ./common.sh
source ./config

[ -f ppid ] && kill -9 $(cat ppid) 2> /dev/null || true
rm -f ppid
