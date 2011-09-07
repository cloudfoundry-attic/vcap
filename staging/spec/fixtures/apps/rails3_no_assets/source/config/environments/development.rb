Rails3Nodb::Application.configure do
  config.cache_classes = false
  config.whiny_nils = true
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log
  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
end

