#!/usr/bin/env ruby

PATH = File.expand_path(File.join("..", ARGV.first), __FILE__)
unless File.directory?(PATH)
  STDERR.puts "%s: No such directory" % $0
  exit 1
end

Dir.chdir(PATH)
require "../.lib/global"

chroot "union"
