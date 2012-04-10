require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'

Gem::PackageTask.new(Gem::Specification.load('vcap_staging.gemspec')).define

desc "build gem"
task :build => :gem

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = ['--color', '--format nested']
end

task :default => [:spec]

desc 'Run tests for CI'
task 'ci:spec' => ['ci:setup:rspec', :spec]
