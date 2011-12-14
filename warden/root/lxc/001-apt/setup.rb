#!/usr/bin/env ruby

require File.expand_path("../../.lib/global", $0)

mount_union

Dir.chdir File.expand_path("../union", $0)

write "etc/apt/sources.list", <<-EOS
deb http://apt-mirror.cso.vmware.com/ubuntu/ lucid main universe
deb http://apt-mirror.cso.vmware.com/ubuntu/ lucid-updates main universe
EOS

# Never show a dialog from dpkg
chroot ".", <<-EOS
echo debconf debconf/frontend select noninteractive |
  debconf-set-selections
EOS

# Install packages
chroot ".", <<-EOS
apt-get update
# apt-get install -y <list of packages>
EOS

# Remove files we don't need
script <<-EOS
rm -f var/cache/apt/archives/*.deb
rm -f var/cache/apt/*cache.bin
rm -f var/lib/apt/lists/*_Packages
EOS
