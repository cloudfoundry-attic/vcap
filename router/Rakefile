require 'ci/reporter/rake/rspec'
require 'rspec/core/rake_task'

namespace :ci do
  desc "Run specs producing results for CI"
  task "spec" => ["ci:setup:rspec", "^spec"]
end

reports_dir = File.expand_path(File.join(File.dirname(__FILE__), "spec_reports"))

task "test" do |t|
  sh("cd spec && rake test")
end

task "spec" do |t|
  sh("cd spec && rake spec")
end

ENV['CI_REPORTS'] = reports_dir
