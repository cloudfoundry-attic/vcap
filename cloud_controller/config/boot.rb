require 'rubygems'
require 'erb'
begin
  require 'fiber'
rescue LoadError
  $stderr.puts "CloudController requires a Ruby implementation that supports Fibers"
  exit 1
end

# Set up gems listed in the Gemfile.
gemfile = File.expand_path('../../Gemfile', __FILE__)
begin
  ENV['BUNDLE_GEMFILE'] = gemfile
  require 'bundler'
  Bundler.setup
rescue Bundler::GemNotFound => e
  STDERR.puts e.message
  STDERR.puts "Try running `bundle install`."
  exit!
end if File.exist?(gemfile)

require 'rack/fiber_pool'

# The CloudController module features some helper methods that
# return normalized config options, and occasionally reprise
# parts of the Rails bootstrap process. This file is also loaded
# by bin/cloudcontroller and by the HealthManager.
module CloudController
  # All fibers that are not associated with a Rack request MUST be spawned from
  # this pool if they plan on hitting the DB. It is registered with the
  # connection pool used with the em_mysql2 adapter and will ensure that
  # connections used by fibers spawned from this pool will be correctly
  # returned to the ActiveRecord connection pool.
  UTILITY_FIBER_POOL = FiberPool.new(500)

  class << self
    def environment
      AppConfig[:rails_environment]
    end

    def current_ruby
      unless defined?(Config)
        require 'rbconfig'
      end
      File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
    end

    def root_dir
      File.expand_path('../..', __FILE__)
    end

    def version
      '0.999'
    end

    def bind_address
      VCAP.local_ip(AppConfig[:local_route])
    end

    # This also sets an environment variable so
    # host information can be passed to subprocesses.
    def bind_address=(addr)
      AppConfig[:local_route] = ENV['CLOUD_CONTROLLER_HOST'] = addr.to_s
    end

    def instance_port
      AppConfig[:instance_port]
    end

    # This also sets an environment variable so
    # port information can be passed to subprocesses.
    def instance_port=(port)
      ENV['CLOUD_CONTROLLER_PORT'] = port.to_s
      AppConfig[:instance_port] = port.to_i
    end

    def pid
      AppConfig[:pid]
    end

    def database_configuration
      # Various Railties expect this to have (recursively) string keys.
      AppConfig[:database_environment].with_indifferent_access
    end
  end
end

unless defined?(AppConfig)
  require File.expand_path('../appconfig', __FILE__)
end
ENV['RAILS_ENV'] = CloudController.environment

# Force 'NOSTART' mode when launching due to Rake.
if File.basename($0) == 'rake'
  # could do.. ARGV.include?('db:migrate') || ARGV.include?('db:schema:load')
  ENV['CC_NOSTART'] = '1'
end
