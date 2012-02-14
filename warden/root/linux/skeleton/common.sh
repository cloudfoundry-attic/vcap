#!/bin/bash

target="union"

function write() {
  [ -z "${1}" ] && return 1

  mkdir -p ${target}/$(dirname ${1})
  cat > ${target}/${1}
}

function chroot() {
  $(which chroot) ${target} env -i /bin/bash
}

function setup_fs() {
  mkdir -p rootfs ${target}
  mount -n -t aufs -o br:rootfs=rw:../../base/rootfs=ro+wh none ${target}
}

function teardown_fs() {
  umount ${target}
}
