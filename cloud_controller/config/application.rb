require File.expand_path('../boot', __FILE__)

# Just load ActiveRecord and ActionController, not ActionMailer or ActiveResource.
require "active_record/railtie"
require "action_controller/railtie"
require "rails/test_unit/railtie"

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

# Settings in config/environments/* take precedence over those specified here.
# Application configuration should go into files in config/initializers

module CloudController
  class << self
    attr_accessor :resource_pool # The configured ResourcePool instance
    attr_accessor :events # The configured Events instance
    attr_accessor :logger
  end

  class Application < Rails::Application
    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Eastern Time (US & Canada)'

    # This is how you disable sessions 'for real' these days.
    config.session_store(nil)
    # JavaScript files you want as :defaults (application.js is always included).
    config.action_view.javascript_expansions[:defaults] = %w()

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive (or huge) parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :_json, :application, :resources]

    # Put deprecation warnings in the logfile
    config.active_support.deprecation = :log

    unless Rails.env.test?
      # Install FiberPool early in the chain. `rake middleware` to see the order.
      config.middleware.insert_before Rails::Rack::Logger, Rack::FiberPool, :size => 512
    end
  end
end

module Rails
  class Application
    class Configuration
      alias original_database_configuration database_configuration

      def database_configuration
        CloudController.database_configuration
      end
    end
  end
end
