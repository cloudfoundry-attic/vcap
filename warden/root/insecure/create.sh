#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <instance name>"
  exit 1
fi

# Change to directory that holds this script
self=$(readlink -f ${0})
cd $(dirname ${self})

cp -r .instance-skeleton .instance-$1
