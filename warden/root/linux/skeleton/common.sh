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

function mount_union() {
  mkdir -p rootfs ${target}
  $(which mount) -t aufs -o br:rootfs=rw:../../base/rootfs=ro+wh none ${target}
}

function umount_union() {
  $(which umount) ${target}
}
