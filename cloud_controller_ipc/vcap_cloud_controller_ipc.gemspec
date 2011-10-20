# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "vcap/cloud_controller/ipc/version"

Gem::Specification.new do |s|
  s.name        = "vcap_cloud_controller_ipc"
  s.version     = VCAP::CloudController::Ipc::VERSION
  s.authors     = ["mpage"]
  s.email       = ["mpage@vmware.com"]
  s.homepage    = "www.cloudfoundry.com"
  s.summary     = %q{Library for communicating with Cloud Controllers}
  s.description = %q{Provides clients for ineracting with CCs}

  s.files         = %w(Rakefile Gemfile) + Dir.glob("{lib,spec}/**/*")
  s.executables   = []
  s.bindir        = 'bin'
  s.require_paths = ["lib"]

  s.add_dependency 'rake'
  s.add_dependency 'yajl-ruby'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'webmock'
end
