#!/bin/bash

set -o nounset
set -o errexit

if [ -z "${SKIP_DEBOOTSTRAP+1}" ]; then
  debootstrap_bin=$(which debootstrap)
else
  debootstrap_bin=""
fi
chroot_bin=$(which chroot)
packages="openssh-server,rsync"
suite="lucid"
target="rootfs"
mirror=$(grep "^deb" /etc/apt/sources.list | head -n1 | cut -d" " -f2)

# Fallback to default Ubuntu mirror when mirror could not be determined
if [ -z "${mirror}" ]; then
  mirror="http://archive.ubuntu.com/ubuntu/"
fi

function debootstrap() {
  if [ -d ${target} ]; then
    read -p "Target directory already exists. Erase it? "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf ${target}
    else
      echo "Aborting..."
      exit 1
    fi
  fi

  ${debootstrap_bin} --verbose --include ${packages} ${suite} ${target} ${mirror}
}

function write() {
  [ -z "${1}" ] && return 1

  mkdir -p ${target}/$(dirname ${1})
  cat > ${target}/${1}
}

function chroot() {
  ${chroot_bin} ${target} env -i $(cat ${target}/etc/environment) /bin/bash
}

if [ ${EUID} -ne 0 ]; then
  echo "Sorry, you need to be root."
  exit 1
fi

if [ "${#}" -ne 1 ]; then
  echo "Usage: setup.sh [base_dir]"
  exit 1
fi

if [ ! -d ${1} ]; then
  echo "Looks like ${1} doesn't exist or isn't a directory"
  exit 1
fi

cd ${1}

if [ -z "${SKIP_DEBOOTSTRAP+1}" ]; then
  debootstrap
fi

if [ -z "${SKIP_APT+1}" ]; then
write "etc/apt/sources.list" <<-EOS
deb ${mirror} lucid main universe
deb ${mirror} lucid-updates main universe
EOS

# Disable initctl so that apt cannot start any daemons
mv ${target}/sbin/initctl ${target}/sbin/initctl.real
ln -s /bin/true ${target}/sbin/initctl
trap "mv ${target}/sbin/initctl.real ${target}/sbin/initctl" EXIT

# Disable interactive dpkg
chroot <<-EOS
echo debconf debconf/frontend select noninteractive |
 debconf-set-selections
EOS

# Install packages
chroot <<-EOS
apt-get update
# apt-get install -y <list of packages>
EOS

# Remove files we don't need or want
chroot <<-EOS
rm -f /var/cache/apt/archives/*.deb
rm -f /var/cache/apt/*cache.bin
rm -f /var/lib/apt/lists/*_Packages
rm -f /etc/ssh/ssh_host_*
EOS
fi

write "lib/init/fstab" <<-EOS
# nothing
EOS

# Disable unneeded services
rm -f ${target}/etc/init/ureadahead*
rm -f ${target}/etc/init/plymouth*
rm -f ${target}/etc/init/hwclock*
rm -f ${target}/etc/init/hostname*
rm -f ${target}/etc/init/*udev*
rm -f ${target}/etc/init/module-*
rm -f ${target}/etc/init/mountall-*
rm -f ${target}/etc/init/mounted-*
rm -f ${target}/etc/init/dmesg*
rm -f ${target}/etc/init/network-*
rm -f ${target}/etc/init/procps*
rm -f ${target}/etc/init/rcS*
rm -f ${target}/etc/init/rsyslog*

# Don't run ntpdate when container network comes up
rm -f ${target}/etc/network/if-up.d/ntpdate

# Don't run cpu frequency scaling
rm -f ${target}/etc/rc*.d/S*ondemand

# Disable selinux
mkdir -p ${target}/selinux
echo 0 > ${target}/selinux/enforce

# Remove console related upstart scripts
rm -f ${target}/etc/init/tty*
rm -f ${target}/etc/init/console-setup.conf

# Strip /dev down to the bare minimum
rm -rf ${target}/dev
mkdir -p ${target}/dev

# /dev/console
# This device is bind-mounted to a pty in the container, but keep it here so
# the container can use its permissions as reference.
file=${target}/dev/console
mknod -m 600 ${file} c 5 1
chown root:tty ${file}

# /dev/tty
file=${target}/dev/tty
mknod -m 666 ${file} c 5 0
chown root:tty ${file}

# /dev/random, /dev/urandom
file=${target}/dev/random
mknod -m 666 ${file} c 1 8
chown root:root ${file}
file=${target}/dev/urandom
mknod -m 666 ${file} c 1 9
chown root:root ${file}

# /dev/null, /dev/zero
file=${target}/dev/null
mknod -m 666 ${file} c 1 3
chown root:root ${file}
file=${target}/dev/zero
mknod -m 666 ${file} c 1 5
chown root:root ${file}

# /dev/fd, /dev/std{in,out,err}
pushd ${target}/dev > /dev/null
ln -s /proc/self/fd
ln -s fd/0 stdin
ln -s fd/1 stdout
ln -s fd/2 stderr
popd > /dev/null
