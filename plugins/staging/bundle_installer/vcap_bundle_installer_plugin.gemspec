require File.expand_path('../lib/vcap/plugins/staging/bundle_installer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "vcap_bundle_installer_plugin"
  gem.authors       = ["mpage"]
  gem.email         = ["mpage@vmware.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = %w(Rakefile Gemfile) + Dir.glob("{lib,spec,assets}/**/*")
  gem.require_paths = ["lib"]
  gem.version       = VCAP::Plugins::Staging::BundleInstaller::VERSION

  gem.add_development_dependency("rspec")
  gem.add_dependency("rake")

  # XXX - PACKAGE CACHE DEPS, REMOVE
  gem.add_dependency('rest-client')
  gem.add_dependency('vcap_common')
  gem.add_dependency('sinatra')
end
