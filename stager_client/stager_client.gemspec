# -*- encoding: utf-8 -*-
require File.expand_path('../lib/vcap/stager/client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["mpage"]
  gem.email         = ["support@cloudfoundry.com"]
  gem.description   = "Provides a stable api for requesting that stagers" \
                      + " perform work."
  gem.summary       = "Gem for communicating with stagers"
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "stager_client"
  gem.require_paths = ["lib"]
  gem.version       = VCAP::Stager::Client::VERSION

  gem.add_development_dependency("rake")
  gem.add_development_dependency("rspec")

  gem.add_dependency("eventmachine")
  gem.add_dependency("nats")
  gem.add_dependency("yajl-ruby")
end
