#!/usr/bin/env ruby

require File.expand_path("../.lib/global", $0)

unless ARGV.first
  STDERR.puts "usage: %s [path to container]" % $0
  exit 1
end

path = File.expand_path("../%s" % ARGV.first, $0)
mount_union(path)

Dir.chdir(path)

chroot "union"
