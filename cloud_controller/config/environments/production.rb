CloudController::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb
  config.cache_classes = true
  config.threadsafe!
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = false
  config.log_level = AppConfig[:rails_logging][:level].downcase.to_sym

  # FIXME - Configure this via AppConfig
  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'
  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files
  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  # config.serve_static_assets = false

  # BOSH needs to be able to override various paths that
  # Rails has strong defaults for.
  # FIXME - Even when not running via BOSH, some of these
  # should likely be set from AppConfig.

  config.active_record.schema_format = :sql
  config.paths.log = AppConfig[:rails_logging][:file]
  tmpdir = AppConfig[:directories][:tmpdir]
  config.paths.tmp = tmpdir
  config.paths.tmp.cache = File.join(tmpdir, 'cache')

  # Setup log rotation for daily
  # config.logger = Logger.new(config.paths.log.first, 'daily')

end
