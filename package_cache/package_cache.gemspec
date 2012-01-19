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
end
