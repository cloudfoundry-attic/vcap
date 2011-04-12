# These tasks are used by both the core Rakefile and the tests/Rakefile.
#
# There are two primary install tasks:
# bundler:install installs everything but the 'production' Gemfile groups
# bundler:install:production installs everything but the 'test' Gemfile groups

namespace :bundler do
  desc "Ensure each component has a complete set of gems installed"
  task :check do
    cmd = "echo `basename $PWD`;bundle check"
    CoreComponents.for_each_gemfile(cmd, "check")
  end

  desc "Removed stored Bundler configuration files"
  task :reset do
    CoreComponents.for_each_gemfile("rm -rf .bundle", "config removal")
  end

  desc "Recalculate component gem dependencies using rubygems.org"
  task :update do
    CoreComponents.for_each_gemfile("bundle update", "update")
  end

  desc "Store latest component gems in vendor/cache"
  task :package do
    CoreComponents.for_each_gemfile("bundle package", "package")
  end

  desc "Install component gems for development and test environments"
  task :install do
    CoreComponents.for_each_gemfile("bundle install --local --without production")
  end
  task :"install:development" => :install

  desc "Install component gems for production environments"
  task :"install:production" do
    cmd = " bundle install --local --without test"
    CoreComponents.for_each_gemfile(cmd, "production install")
  end

  # No description, deprecated.
  task :"install:test" do
    $stderr.puts "WARN: Deprecated installation task. bundler:install will install the :test dependencies."
    CoreComponents.for_each_gemfile("bundle install --local --without production development")
  end
end

# vim: ts=2 sw=2 filetype=ruby
