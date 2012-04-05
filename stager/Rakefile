require 'rubygems'
require 'rake'
require 'rake/gempackagetask'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'vcap/stager/version'

GEM_NAME    = 'vcap_stager'
GEM_VERSION = VCAP::Stager::VERSION

gemspec = Gem::Specification.new do |s|
  s.name         = GEM_NAME
  s.version      = GEM_VERSION
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
  s.files        = %w(Rakefile Gemfile) + Dir.glob("{lib,spec,vendor}/**/*")
end

Rake::GemPackageTask.new(gemspec) do |pkg|
  pkg.gem_spec = gemspec
end

task :install => [:package] do
  sh "gem install --no-ri --no-rdoc pkg/#{GEM_NAME}-#{GEM_VERSION}"
end

task :spec => ['bundler:install:test'] do
  desc 'Run tests'
  sh('cd spec && rake spec')
end

task 'ci:spec' do
  desc 'Run tests for CI'
  sh('cd spec && rake ci:spec')
end

namespace 'bundler' do
  task 'install' do
    sh('bundle install')
  end

  environments = %w(test development production)
  environments.each do |env|
    desc "Install gems for #{env}"
    task "install:#{env}" do
      sh("bundle install --local --without #{(environments - [env]).join(' ')}")
    end
  end
end
