Rails3Nodb::Application.configure do
  config.cache_classes = true
  config.whiny_nils = true
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.action_dispatch.show_exceptions = false
  config.action_controller.allow_forgery_protection    = false
  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr
end
