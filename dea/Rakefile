require 'rake'
require 'ci/reporter/rake/rspec'

desc "Run specs"
task "spec" => ["bundler:install:test", "test:spec"]

desc "Run specs using RCov"
task "spec:rcov" => ["bundler:install:test", "test:spec:rcov"]

desc "Run specs producing results for CI"
task "ci" => ["ci:spec"]

namespace "bundler" do
  desc "Install gems"
  task "install" do
    sh("bundle install")
  end

  desc "Install gems for test"
  task "install:test" do
    sh("bundle install --without development production")
  end

  desc "Install gems for production"
  task "install:production" do
    sh("bundle install --without development test")
  end

  desc "Install gems for development"
  task "install:development" do
    sh("bundle install --without test production")
  end
end

namespace "test" do
  task "spec" do |t|
    sh("cd spec && rake spec")
  end

 task "spec:rcov" do |t|
    sh("cd spec && rake spec:rcov")
  end
end

namespace :ci do
  task "spec" => ["ci:setup:rspec", "^spec"]
end
