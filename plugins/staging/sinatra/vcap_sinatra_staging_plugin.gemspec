# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "vcap/plugins/staging/sinatra_staging_plugin/version"

Gem::Specification.new do |s|
  s.name        = "vcap_sinatra_staging_plugin"
  s.version     = VCAP::Plugins::Staging::SinatraStagingPlugin::VERSION
  s.authors     = ["mpage"]
  s.email       = ["mpage@vmware.com"]
  s.homepage    = "http://www.cloudfoundry.com"
  s.summary     = %q{Stages sinatra applications for deployment in Cloud Foundry.}
  s.description = %q{Modifies applications for deployment in CF.}

  s.rubyforge_project = "vcap_sinatra_staging_plugin"

  s.files         = %w(Rakefile Gemfile) + Dir.glob("{lib,spec,assets,test_assets}/**/*")
  s.executables   = []
  s.bindir        = 'bin'
  s.require_paths = ["lib"]

  # XXX - These need to be development dependencies. Figure out why bundler isn't installing
  #       them later...
  s.add_dependency("rspec")
  s.add_dependency("rspec-core")
  s.add_dependency("rake")
end
