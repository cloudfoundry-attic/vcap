require 'secure_user_manager'
require 'vcap/staging/plugin/common'

StagingPlugin.manifest_root = AppConfig[:directories][:staging_manifests]
# Activates the staging plugins and loads all included YAML files
StagingPlugin.load_all_manifests

# Setup secure mode if asked
SecureUserManager.instance.setup if AppConfig[:staging][:secure]
