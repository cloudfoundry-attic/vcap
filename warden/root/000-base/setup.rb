#!/usr/bin/env ruby

PATH = File.expand_path("..", __FILE__)
Dir.chdir(PATH)
require "../.lib/global"

packages = %w(ubuntu-minimal).join(",")
suite = "lucid"
target = "union"
mirror = "http://ftp.cs.stanford.edu/mirrors/ubuntu/"

args = ["/usr/sbin/debootstrap"] +
  ["--verbose"] +
  ["--variant=minbase"] +
  ["--include", packages] +
  [suite] +
  [target] +
  [mirror]

unless system(*args)
  error "debootstrap failed..."
end
