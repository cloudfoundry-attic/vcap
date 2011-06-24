require 'secure_user_manager'

ENV['STAGING_CONFIG_DIR'] = AppConfig[:directories][:staging_manifests]
# Activates the staging plugins and loads all included YAML files
require Rails.root.join('staging', 'common')
StagingPlugin.load_all_manifests

# Setup secure mode if asked
SecureUserManager.instance.setup if AppConfig[:staging][:secure]
