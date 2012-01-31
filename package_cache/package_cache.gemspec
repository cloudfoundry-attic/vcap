# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "vcap/package_cache/version"

Gem::Specification.new do |s|
  s.name         = 'vcap_package_cache'
  s.version      = VCAP::PackageCache::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'builds and caches packages e.g. (gem\'s)'
  s.description  = 'Takes the name of a remote package or path to a local package' \
                   + 'builds it for a given runtime e.g. ruby18, and stores it for'\
                   + 'later use by the stager.'
  s.authors      = ['Tal Garfinkel']
  s.email        = 'talg@vmware.com'
  s.homepage     = 'http://www.cloudfoundry.com'
  s.executables  = []
  s.bindir       = 'bin'
  s.require_path = 'lib'
  s.files        = Dir.glob("**/*")

  s.add_dependency('rake', '0.9.2.2')
  s.add_dependency('thin', '1.3.1')
  s.add_dependency('sinatra', '1.3.2')
  s.add_dependency('vcap_common', '~> 1.0.6')
  s.add_dependency('vcap_logging', '>= 0.1.1')
  s.add_dependency('vcap_package_cache_client', '0.1.8')

end
