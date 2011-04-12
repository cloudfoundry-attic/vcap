CloudController::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # FIXME - Even with 'config.threadsafe!' set after this file loads,
  # it is still possible to observe code reloading.
  # For now we explicitly configure 'threadsafe!' in each environment.
  config.cache_classes = true
  config.threadsafe!

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  # config.action_mailer.raise_delivery_errors = false

  # See everything in the log (default is :info)
  config.log_level = :debug

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Setup log rotation for daily
  # config.logger = Logger.new(config.paths.log.first, 'daily')

end

