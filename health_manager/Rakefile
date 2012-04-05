ENV["BUNDLE_GEMFILE"] = File.expand_path("../../cloud_controller/Gemfile", __FILE__)
require 'rspec/core/rake_task'
require 'ci/reporter/rake/rspec'

ENV['RAILS_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'

# FIXME - This does not honor the test db set in
# config/health_manager.yml
# TODO HACK FAIL
task "prepare_test_db" do
  cc_root = File.expand_path("../../cloud_controller", __FILE__)
  Dir.chdir(cc_root) do
    ruby "-S rake RAILS_ENV=test db:migrate >/dev/null 2>/dev/null"
  end
end

reports_dir = File.expand_path("spec_reports")

ENV['CI_REPORTS'] = reports_dir

RSpec::Core::RakeTask.new do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.rspec_opts = ["--format", "documentation", "--colour"]
end

namespace :ci do
  desc "Run specs producing results for CI"
  task "spec" => ["ci:setup:rspec", "^spec"]
end
