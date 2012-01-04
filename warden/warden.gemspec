# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "warden/version"

Gem::Specification.new do |s|
  s.name        = "warden"
  s.version     = Warden::VERSION
  s.authors     = ["Pieter Noordhuis", "Matt Page"]
  s.email       = ["pcnoordhuis@gmail.com", "mpage@vmware.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "warden"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "eventmachine", "0.12.11.cloudfoundry.3"
  s.add_runtime_dependency "yajl-ruby"
  s.add_runtime_dependency "em-posix-spawn", '> 0.0.1'
  s.add_runtime_dependency "vcap_common"
  s.add_runtime_dependency "sleepy_penguin"
end
