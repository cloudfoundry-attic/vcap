#!/usr/bin/env ruby

PATH = File.expand_path("..", __FILE__)
Dir.chdir(PATH)
require "../.lib/global"

Dir.chdir("union")

write "etc/fstab", <<-EOS
tmpfs /dev/shm tmpfs defaults 0 0
EOS

# Disable unneeded mount points
file = "lib/init/fstab"
write file, IO.readlines(file).
  find_all { |line|
    line !~ %r!\s/(proc|sys|spu|dev)\s!i
  }.join

# Disable unneeded services
sh "rm -f etc/init/tty*"
sh "rm -f etc/init/ureadahead*"
sh "rm -f etc/init/plymouth*"
sh "rm -f etc/init/hwclock*"
sh "rm -f etc/init/hostname*"

# Removing these udev upstart files causes tty1 not to work
sh "rm -f etc/init/udev{monitor,trigger,-finish}.conf"

# Don't run ntpdate when container network comes up
sh "rm -f etc/network/if-up.d/ntpdate"
