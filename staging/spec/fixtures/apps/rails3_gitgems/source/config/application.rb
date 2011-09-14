require File.expand_path('../boot', __FILE__)
require 'action_controller/railtie'
Bundler.require(:default, Rails.env) if defined?(Bundler)

module Rails3Nodb
  class Application < Rails::Application
    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"
  end
end
