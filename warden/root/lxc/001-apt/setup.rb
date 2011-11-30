#!/usr/bin/env ruby

PATH = File.expand_path("..", __FILE__)
Dir.chdir(PATH)
require "../.lib/global"

Dir.chdir("union")

write "etc/apt/sources.list", <<-EOS
deb http://us.archive.ubuntu.com/ubuntu/ lucid main universe
deb http://us.archive.ubuntu.com/ubuntu/ lucid-updates main universe
EOS

# Never show a dialog from dpkg
chroot ".", <<-EOS
echo debconf debconf/frontend select noninteractive |
  debconf-set-selections
EOS

# Install packages
chroot ".", <<-EOS
apt-get update
apt-get install -y socat
EOS

# Remove files we don't need
script <<-EOS
rm -f var/cache/apt/archives/*.deb
rm -f var/cache/apt/*cache.bin
rm -f var/lib/apt/lists/*_Packages
EOS
