$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'vcap/staging/version'

gemspec = Gem::Specification.new do |s|
  s.name         = 'vcap_staging'
  s.version      = VCAP::Staging::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'Plugins responsible for creating executable droplets'
  s.description  = s.summary
  s.authors      = []
  s.email        = ''
  s.homepage     = 'http://www.cloudfoundry.com'

  s.add_dependency('nokogiri', '>= 1.4.4')
  s.add_dependency('rake')
  s.add_dependency('yajl-ruby', '>= 0.7.9')

  s.add_dependency('rspec')

  s.add_dependency('vcap_common')

  s.executables  = []
  s.bindir       = 'bin'
  s.require_path = 'lib'

  s.files        = %w(Rakefile) + Dir.glob("{lib,spec,vendor}/**/*")
end
