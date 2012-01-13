# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "warden/version"

Gem::Specification.new do |s|
  s.name        = "warden"
  s.version     = Warden::VERSION
  s.authors     = ["Pieter Noordhuis", "Matt Page"]
  s.email       = ["pcnoordhuis@gmail.com", "mpage@vmware.com"]
  s.homepage    = "http://www.cloudfoundry.com"
  s.summary     = "A tool for managing ephemeral containers."
  s.description = <<-EOT
The warden provides an API for creating and managing containers.
The specific kind of container provided by the warden may be chosen
at runtime. Currently it supports an insecure container (mainly for
development) and one that uses Linux cgroup functionality.
EOT

  s.rubyforge_project = "warden"

  s.files         = Dir.glob("**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.executables   = ["warden-repl"]
  s.require_paths = ["lib"]

  s.add_runtime_dependency "bundler", "> 1.0.20"
  s.add_runtime_dependency "eventmachine", "0.12.11.cloudfoundry.3"
  s.add_runtime_dependency "yajl-ruby"
  s.add_runtime_dependency "em-posix-spawn", '> 0.0.1'
  s.add_runtime_dependency "vcap_common"
  s.add_runtime_dependency "sleepy_penguin"
end
