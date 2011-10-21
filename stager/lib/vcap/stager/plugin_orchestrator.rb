require 'fileutils'
require 'rubygems'


require 'vcap/cloud_controller/ipc'
require 'vcap/logging'
require 'vcap/stager/constants'
require 'vcap/stager/droplet'
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
  # @param source_dir      String  Directory containing application source
  # @param dest_dir        String  Directory where the staged droplet should live
  # @param app_properties
  # @param cc_info         Hash    Information needed for contacting the CC
  #                                  'host'
  #                                  'port'
  #                                  'task_id'
  def initialize(source_dir, dest_dir, app_properties, cc_info)
    @source_dir      = source_dir
    @dest_dir        = dest_dir
    @droplet         = VCAP::Stager::Droplet.new(dest_dir)
    @app_properties  = app_properties
    @logger          = VCAP::Logging.logger('vcap.stager.plugin_orchestrator')
    @services_client = VCAP::CloudController::Ipc::ServiceConsumerV1Client.new(cc_info['host'],
                                                                               cc_info['port'],
                                                                               :staging_task_id => cc_info['task_id'])
  end

  def run_plugins
    for plugin_info in @app_properties['plugins']
      require(plugin_info['gem']['name'])
    end

    framework_plugin, feature_plugins = collect_plugins
    unless framework_plugin
      raise VCAP::Stager::MissingFrameworkPluginError, "No framework plugin found"
    end

    @logger.info("Setting up base droplet structure")
    @droplet.create_skeleton(@source_dir)

    actions = VCAP::Stager::PluginActionProxy.new(@droplet.framework_start_path,
                                                  @droplet.framework_stop_path,
                                                  @droplet,
                                                  @services_client)
    @logger.info("Running framework plugin: #{framework_plugin.name}")
    framework_plugin.stage(@droplet.app_source_dir, actions, @app_properties)

    for feature_plugin in feature_plugins
      pname = feature_plugin.name
      actions = VCAP::Stager::PluginActionProxy.new(@droplet.feature_start_path(pname),
                                                    @droplet.feature_stop_path(pname),
                                                    @droplet,
                                                    @services_client)
      @logger.info("Running feature plugin: #{feature_plugin.name}")
      feature_plugin.stage(framework_plugin, @droplet.app_source_dir, actions, @app_properties)
    end
  end

  protected

  def collect_plugins
    framework_plugin = nil
    feature_plugins  = []
    for plugin in VCAP::Stager::PluginRegistry.plugins
      ptype = plugin.plugin_type
      case ptype
      when :framework
        @logger.debug("Found framework plugin: #{plugin.name}")
        if framework_plugin
          raise VCAP::Stager::DuplicateFrameworkPluginError, "Only one framework plugin allowed"
        else
          framework_plugin = plugin
        end

      when :feature
        @logger.debug("Found feature plugin: #{plugin.name}")
        feature_plugins << plugin

      else
        raise VCAP::Stager::UnknownPluginTypeError, "Unknown plugin type: #{ptype}"

      end
    end

    [framework_plugin, feature_plugins]
  end

end
