require 'vcap/plugin_registry'
require 'vcap/plugins/staging/sinatra'

VCAP::PluginRegistry.register_plugins(VCAP::Plugins::Staging::Sinatra.new)
