#!/usr/bin/env ruby

require File.expand_path("../../.lib/global", $0)

mount_union

Dir.chdir File.expand_path("..", $0)

packages = %w(ubuntu-minimal).join(",")
suite = "lucid"
target = "union"
mirror = "http://apt-mirror.cso.vmware.com/ubuntu/"

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
