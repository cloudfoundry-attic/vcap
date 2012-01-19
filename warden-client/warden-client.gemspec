# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "warden/client/version"

Gem::Specification.new do |s|
  s.name        = "warden-client"
  s.version     = Warden::Client::VERSION
  s.authors     = ["Pieter Noordhuis", "Matt Page"]
  s.email       = ["pcnoordhuis@gmail.com", "mpage@vmware.com"]
  s.homepage    = "http://www.cloudfoundry.org/"
  s.summary     = %q{Client driver for warden, the ephemeral container manager.}
  s.description = %q{}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "yajl-ruby"
end
