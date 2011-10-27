require 'rubygems'

require 'vcap/logging'

require 'vcap/stager/plugin_action_proxy'
require 'vcap/stager/plugin_orchestrator_error'
require 'vcap/stager/plugin_registry'

module VCAP
  module Stager
  end
end

# Responsible for orchestrating the execution of all staging plugins selected
# by the user.
class VCAP::Stager::PluginOrchestrator
  # @param source_dir     String  Directory containing application source
  # @param app_properties
  def initialize(source_dir, app_properties)
    @source_dir     = source_dir
    @app_properties = app_properties
    @logger         = VCAP::Logging.logger('vcap.stager.plugin_orchestrator')
  end

  def run_plugins
    for name, props in @app_properties.plugins
      require(name)
    end

    framework_plugin = nil
    feature_plugins = []
    for plugin in VCAP::Stager::PluginRegistry.plugins
      ptype = plugin.plugin_type
      case ptype
      when :framework
        @logger.debug("Found framework plugin: #{name}")
        if framework_plugin
          raise VCAP::Stager::DuplicateFrameworkPluginError, "Only one framework plugin allowed"
        else
          framework_plugin = plugin
        end

      when :feature
        @logger.debug("Found feature plugin: #{name}")
        feature_plugins << plugin

      else
        raise VCAP::Stager::UnknownPluginTypeError, "Unknown plugin type: #{ptype}"

      end
    end

    raise VCAP::Stager::MissingFrameworkPluginError, "No framework plugin found" unless framework_plugin

    actions = VCAP::Stager::PluginActionProxy.new
    @logger.info("Running framework plugin: #{framework_plugin.name}")
    framework_plugin.stage(@source_dir, actions, @app_properties)
    for feature_plugin in feature_plugins
      @logger.info("Running feature plugin: #{feature_plugin.name}")
      feature_plugin.stage(framework_plugin, @source_dir, actions, @app_properties)
    end
  end
end
