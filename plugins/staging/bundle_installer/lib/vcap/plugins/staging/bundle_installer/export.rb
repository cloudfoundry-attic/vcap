require 'vcap/plugin_registry'
require 'vcap/plugins/staging/bundle_installer'

VCAP::PluginRegistry.register_plugins(VCAP::Plugins::Staging::BundleInstaller.new)
