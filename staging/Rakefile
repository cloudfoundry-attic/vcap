require 'rake'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'vcap/staging/version'

task :build do
  sh "gem build vcap_staging.gemspec"
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
