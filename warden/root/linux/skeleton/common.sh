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
  if [ ! -f fs ]; then
    dd if=/dev/null of=fs bs=1k seek=512k
    mkfs.ext2 -q -F fs
  fi

  mkdir -p rootfs ${target}
  mount -n -o loop fs rootfs

  codename=$(lsb_release -c -s)

  case "${codename}" in

  lucid|natty|oneiric)
    mount -n -t aufs -o br:rootfs=rw:../../base/rootfs=ro+wh none ${target}
    ;;

  precise)
    mount -n -t overlayfs -o rw,upperdir=rootfs,lowerdir=../../base/rootfs none ${target}
    ;;

  *)
    echo "Unsupported: '${codename}'"
    exit 1
    ;;

  esac
}

function teardown_fs() {
  umount ${target}
  umount rootfs
}
