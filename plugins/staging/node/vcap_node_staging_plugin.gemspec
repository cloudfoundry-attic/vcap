$:.push File.expand_path("../lib", __FILE__)
require 'vcap/plugins/staging/node/version'

Gem::Specification.new do |s|
  s.name        = "vcap_node_staging_plugin"
  s.version     = VCAP::Plugins::Staging::Node::VERSION
  s.authors     = ["mpage"]
  s.email       = ["mpage@vmware.com"]
  s.homepage    = ""
  s.summary     = 'Stages node applications for CF'
  s.description = 'Modifies node applications so that they can be run in CF'

  s.files         = %w(Rakefile Gemfile) + Dir.glob("{lib,spec,assets}/**/*")
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_dependency "rake"
end
