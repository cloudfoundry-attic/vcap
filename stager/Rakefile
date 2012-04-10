require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'

gemspec = Gem::Specification.load('vcap_stager.gemspec')
gem_package_task = Gem::PackageTask.new(gemspec) {}
gem_path = File.join(gem_package_task.package_dir, gemspec.full_name)

desc "Install #{gem_path}"
task :install => [:package] do
  sh "gem install --no-ri --no-rdoc #{gem_path}"
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = ['--color', '--format nested']
end

desc "Run specs producing results for CI"
task 'ci:spec' => ['ci:setup:rspec', :spec]
