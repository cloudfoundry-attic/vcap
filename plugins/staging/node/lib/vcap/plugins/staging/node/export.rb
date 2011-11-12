require 'vcap/plugin_registry'
require 'vcap/plugins/staging/node'

VCAP::PluginRegistry.register_plugins(VCAP::Plugins::Staging::Node.new)
