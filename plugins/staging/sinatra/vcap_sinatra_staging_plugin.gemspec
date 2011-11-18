$:.push File.expand_path("../lib", __FILE__)
require "vcap/plugins/staging/sinatra/version"

Gem::Specification.new do |s|
  s.name        = "vcap_sinatra_staging_plugin"
  s.version     = VCAP::Plugins::Staging::SinatraStagingPlugin::VERSION
  s.authors     = ["mpage"]
  s.email       = ["mpage@vmware.com"]
  s.homepage    = "http://www.cloudfoundry.com"
  s.summary     = %q{Stages sinatra applications for deployment in Cloud Foundry.}
  s.description = %q{Modifies applications for deployment in CF.}

  s.files         = %w(Rakefile Gemfile) + Dir.glob("{lib,spec,assets,test_assets}/**/*")
  s.executables   = []
  s.bindir        = 'bin'
  s.require_paths = ["lib"]

  s.add_development_dependency("rspec")
  s.add_development_dependency("rake")
end
