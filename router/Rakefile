require 'ci/reporter/rake/rspec'
require 'rspec/core/rake_task'

namespace :ci do
  desc "Run specs producing results for CI"
  task "spec" => ["ci:setup:rspec", "^spec"]
end

reports_dir = File.expand_path(File.join(File.dirname(__FILE__), "spec_reports"))

ENV['CI_REPORTS'] = reports_dir

RSpec::Core::RakeTask.new do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.rspec_opts = ["--format", "documentation", "--colour"]
end
