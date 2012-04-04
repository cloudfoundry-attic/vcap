$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'vcap/stager/version'

gemspec = Gem::Specification.new do |s|
  s.name         = 'vcap_stager'
  s.version      = VCAP::Stager::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'Component responsible for staging apps'
  s.description  = 'Takes an app package, environment, and services' \
                   + ' and produces a droplet that is executable by the DEA'
  s.authors      = ['Matt Page']
  s.email        = 'mpage@vmware.com'
  s.homepage     = 'http://www.cloudfoundry.com'
  s.executables  = []
  s.bindir       = 'bin'
  s.require_path = 'lib'
  s.files        = %w(Rakefile Gemfile) + Dir.glob("{lib,spec}/**/*")
end
