# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'vcap/stager/ipc/version'

Gem::Specification.new do |s|
  s.name        = 'vcap_stager_ipc'
  s.version     = VCAP::Stager::Ipc::VERSION
  s.authors     = ["mpage"]
  s.email       = ["mpage@vmware.com"]
  s.homepage    = "http://www.cloudfoundry.com"
  s.summary     = %q{Library for communicating with stagers}
  s.description = %q{Provides implementations of clients/types used when communicating with stagers.}

  s.files         = %w(Rakefile Gemfile) + Dir.glob("{lib,spec,assets,test_assets}/**/*")
  s.executables   = []
  s.bindir        = 'bin'
  s.require_paths = ["lib"]

  s.add_dependency 'eventmachine'
  s.add_dependency 'rake'
  s.add_dependency 'vcap_common'
  s.add_dependency 'vcap_logging'
  s.add_dependency 'yajl-ruby'

  s.add_development_dependency 'rspec'
end
