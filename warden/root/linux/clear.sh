#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

rm -rf tmp

for instance in instances/*; do
  ./destroy.sh $(basename ${instance}) &
done

wait
