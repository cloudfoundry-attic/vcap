#!/bin/bash

if [ $(whoami) != "root" ]; then
  echo "you are not root"
  exit 1
fi

instances=$(find . -maxdepth 1 -name '.instance-*' -not -name '*-skeleton')
for instance in ${instances}; do

  stop_script=${instance}/stop.sh
  if [ -f ${stop_script} ]; then
    echo "stopping ${instance}..."
    ${stop_script}
  fi

  union_directory=${instance}/union
  if [ -d ${union_directory} ]; then
    echo "unmounting ${union_directory}..."
    umount ${union_directory}
  fi

  echo "removing ${instance}..."
  rm -rf ${instance}
done
