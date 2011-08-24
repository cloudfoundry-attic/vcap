db_config = Rails.application.config.database_configuration[::Rails.env]
if db_config['adapter'] == 'em_mysql2'
  require File.expand_path('../active_record_fiber_patches', __FILE__)
  ActiveRecord::ConnectionAdapters.register_fiber_pool(CloudController::UTILITY_FIBER_POOL)
end

