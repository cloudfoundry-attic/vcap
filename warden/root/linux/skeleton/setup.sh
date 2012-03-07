#!/bin/bash

set -o nounset
set -o errexit
shopt -s nullglob
cd $(dirname "${0}")

source ./common.sh

# Defaults for debugging the setup script
id=${id:-test}
network_gateway_ip=${network_gateway_ip:-10.0.0.1}
network_container_ip=${network_container_ip:-10.0.0.2}
network_netmask=${network_netmask:-255.255.255.252}
copy_root_password=${copy_root_password:-0}

# These variables are always synthesized from the instance id
network_iface_host="veth-${id}-0"
network_iface_container="veth-${id}-1"

# Write configuration
cat > config <<-EOS
id=${id}
network_gateway_ip=${network_gateway_ip}
network_container_ip=${network_container_ip}
network_netmask=${network_netmask}
copy_root_password=${copy_root_password}
network_iface_host=${network_iface_host}
network_iface_container=${network_iface_container}
EOS

setup_fs
trap "teardown_fs" EXIT

write "etc/hostname" <<-EOS
${id}
EOS

write "etc/hosts" <<-EOS
127.0.0.1 ${id} localhost
EOS

write "etc/network/interfaces" <<-EOS
auto lo
iface lo inet loopback
auto ${network_iface_container}
iface ${network_iface_container} inet static
  gateway ${network_gateway_ip}
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

# Fake udev upstart triggers
write "etc/init/fake-udev.conf" <<-EOS
start on startup
script
  /sbin/initctl emit stopped JOB=udevtrigger --no-wait
  /sbin/initctl emit started JOB=udev --no-wait
end script
EOS

# Modify sshd_config
chroot <<-EOS
# Delete comments and empty lines
sed -i -e '/^\($\|#\)/d' /etc/ssh/sshd_config
# Don't allow env vars to propagate over ssh
sed -i -e '/^AcceptEnv/d' /etc/ssh/sshd_config
# Pick up authorized keys from /etc/ssh
echo AuthorizedKeysFile /etc/ssh/authorized_keys/%u >> /etc/ssh/sshd_config
EOS

# Setup host keys for SSH
mkdir -p ssh
ssh-keygen -t rsa -N '' -C "${id}@$(hostname)" -f ssh/ssh_host_rsa_key
cp ssh/ssh_host_rsa_key* ${target}/etc/ssh/
ssh-keygen -t dsa -N '' -C "${id}@$(hostname)" -f ssh/ssh_host_dsa_key
cp ssh/ssh_host_dsa_key* ${target}/etc/ssh/

# Setup access keys for SSH
ssh-keygen -t rsa -N '' -C '' -f ssh/access_key
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
Host container
HostName ${network_container_ip}
EOS

# The `mesg` tool modifies permissions on stdin. Warden regularly passes a
# custom stdin, which makes `mesg` complain that stdin is not a tty. Instead of
# removing all occurances of `mesg`, we simply bind it to /bin/true.
chroot <<EOS
rm /usr/bin/mesg
ln -s /bin/true /usr/bin/mesg
EOS
