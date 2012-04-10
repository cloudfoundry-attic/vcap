#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh

# Defaults for debugging the setup script
id=${id:-test}
network_netmask=${network_netmask:-255.255.255.252}
network_host_ip=${network_host_ip:-10.0.0.1}
network_host_iface="veth-${id}-0"
network_container_ip=${network_container_ip:-10.0.0.2}
network_container_iface="veth-${id}-1"
disk_size_mb=${disk_size_mb:-512}

# Write configuration
cat > config <<-EOS
id=${id}
network_netmask=${network_netmask}
network_host_ip=${network_host_ip}
network_host_iface=${network_host_iface}
network_container_ip=${network_container_ip}
network_container_iface=${network_container_iface}
disk_size_mb=${disk_size_mb}
EOS

setup_fs
trap "teardown_fs" EXIT

write "etc/hostname" <<-EOS
${id}
EOS

write "etc/hosts" <<-EOS
127.0.0.1 ${id} localhost
${network_host_ip} host
${network_container_ip} container
EOS

write "etc/network/interfaces" <<-EOS
auto lo
iface lo inet loopback
auto ${network_container_iface}
iface ${network_container_iface} inet static
  gateway ${network_host_ip}
  address ${network_container_ip}
  netmask ${network_netmask}
EOS

# Inherit nameserver(s)
cp /etc/resolv.conf ${target}/etc/

# Add vcap user if not already present
chroot <<-EOS
if ! id vcap > /dev/null 2>&1
then
useradd -mU -s /bin/bash vcap
fi
EOS

# Copy override directory
cp -r override/* ${target}/

# Remove things we don't use
rm -rf ${target}/etc/init.d
rm -rf ${target}/etc/rc*
rm -f ${target}/etc/init/control-alt-delete.conf
rm -f ${target}/etc/init/rc.conf
rm -f ${target}/etc/init/rc-sysinit.conf
rm -f ${target}/etc/init/cron*
rm -f ${target}/etc/network/if-up.d/openssh*

# Modify sshd_config
chroot <<-EOS
# Delete comments and empty lines
sed -i -e '/^\($\|#\)/d' /etc/ssh/sshd_config
# Don't allow env vars to propagate over ssh
sed -i -e '/^AcceptEnv/d' /etc/ssh/sshd_config
# Don't use dsa host key
sed -i -e '/^HostKey .*dsa/d' /etc/ssh/sshd_config
# Pick up authorized keys from /etc/ssh
echo AuthorizedKeysFile /etc/ssh/authorized_keys/%u >> /etc/ssh/sshd_config
# Never do DNS lookups
echo UseDNS no >> /etc/ssh/sshd_config
EOS

tmp=$(pwd)/../../tmp/
mkdir -p ${tmp}

# Setup host keys for SSH
mkdir -p ssh
if [ -f ${tmp}/ssh_host_rsa_key ]; then
  cp ${tmp}/ssh_host_rsa_key* ssh/
else
  ssh-keygen -t rsa -N '' -C "${id}@$(hostname)" -f ssh/ssh_host_rsa_key
  cp ssh/ssh_host_rsa_key* ${tmp}
fi

cp ssh/ssh_host_rsa_key* ${target}/etc/ssh/

# Setup access keys for SSH
if [ -f ${tmp}/access_key ]; then
  cp ${tmp}/access_key* ssh/
else
  ssh-keygen -t rsa -N '' -C '' -f ssh/access_key
  cp ssh/access_key* ${tmp}
fi

mkdir -p ${target}/etc/ssh/authorized_keys
cat ssh/access_key.pub >> ${target}/etc/ssh/authorized_keys/root
chmod 644 ${target}/etc/ssh/authorized_keys/root
cat ssh/access_key.pub >> ${target}/etc/ssh/authorized_keys/vcap
chmod 644 ${target}/etc/ssh/authorized_keys/vcap

# Add host key to known_hosts
echo -n "${network_container_ip} " >> ssh/known_hosts
cat ssh/ssh_host_rsa_key.pub >> ssh/known_hosts

# Add ssh client configuration
cat <<-EOS > ssh/ssh_config
StrictHostKeyChecking yes
UserKnownHostsFile $(pwd)/ssh/known_hosts
IdentityFile $(pwd)/ssh/access_key
ControlPath $(pwd)/ssh/control-%r@%h
Host container
HostName ${network_container_ip}
Host ${id}
HostName ${network_container_ip}
EOS

# The `mesg` tool modifies permissions on stdin. Warden regularly passes a
# custom stdin, which makes `mesg` complain that stdin is not a tty. Instead of
# removing all occurances of `mesg`, we simply bind it to /bin/true.
chroot <<EOS
rm /usr/bin/mesg
ln -s /bin/true /usr/bin/mesg
EOS
