Rails3Nodb::Application.configure do
  config.cache_classes = true
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true
  config.serve_static_assets = false
  config.action_dispatch.x_sendfile_header = "X-Sendfile"
  config.threadsafe!
  config.i18n.fallbacks = true
  config.active_support.deprecation = :log
end
