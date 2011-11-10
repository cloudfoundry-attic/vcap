require 'erb'
require 'fileutils'
require 'yaml'

require 'vcap/cloud_controller/ipc'
require 'vcap/logging'
require 'vcap/plugin_registry'

require 'vcap/stager/constants'
require 'vcap/stager/errors'
require 'vcap/stager/droplet'
require 'vcap/stager/plugin_action_proxy'

module VCAP
  module Stager
  end
end

# Responsible for orchestrating the execution of all staging plugins selected
# by the user.
class VCAP::Stager::PluginRunner
  RUNNER_BIN_PATH = File.join(VCAP::Stager::BIN_DIR, 'plugin_runner')

  class << self
    def from_file(src_path)
      YAML.load_file(src_path)
    end
  end

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
    @services_client = VCAP::CloudController::Ipc::ServiceConsumerV1Client.new(cc_info['host'],
                                                                               cc_info['port'],
                                                                               :staging_task_id => cc_info['task_id'])
    @environment     = {}
  end

  def run_plugins
    @logger = VCAP::Logging.logger('vcap.stager.plugin_runner')

    framework_plugin, feature_plugins = collect_plugins

    @logger.info("Setting up base droplet structure")
    @droplet.create_skeleton(@source_dir)

    actions = VCAP::Stager::PluginActionProxy.new(@droplet.framework_start_path,
                                                  @droplet.framework_stop_path,
                                                  @droplet,
                                                  @services_client,
                                                  @environment)
    @logger.info("Running framework plugin: #{framework_plugin.name}")
    framework_plugin.stage(@droplet.app_source_dir, actions, @app_properties)

    for feature_plugin in feature_plugins
      pname = feature_plugin.name
      actions = VCAP::Stager::PluginActionProxy.new(@droplet.feature_start_path(pname),
                                                    @droplet.feature_stop_path(pname),
                                                    @droplet,
                                                    @services_client,
                                                    @environment)
      @logger.info("Running feature plugin: #{feature_plugin.name}")
      feature_plugin.stage(framework_plugin, @droplet.app_source_dir, actions, @app_properties)
    end

    @droplet.generate_vcap_start_script(@environment)
  end

  # Serializes *self* to the supplied path
  #
  # @param  dest_path  String  Where to serialize ourselves
  def to_file(dest_path)
    File.open(dest_path, 'w+') do |f|
      YAML.dump(self, f)
    end
  end

  protected

  def collect_plugins
    framework_plugin = nil
    feature_plugins  = []

    for name in @app_properties['plugins'].keys
      plugin = VCAP::PluginRegistry.plugins[name]
      unless plugin
        raise VCAP::Stager::UnsupportedPluginError, name
      end

      ptype = plugin.staging_plugin_type
      case ptype
      when :framework
        @logger.debug("Found framework plugin: #{name}")
        if framework_plugin
          errstr = [framework_plugin.name, name].join(', ')
          raise VCAP::Stager::DuplicateFrameworkPluginError, errstr
        else
          framework_plugin = plugin
        end

      when :feature
        @logger.debug("Found feature plugin: #{name}")
        feature_plugins << plugin

      else
        raise VCAP::Stager::UnknownPluginTypeError, ptype

      end
    end
    unless framework_plugin
      raise VCAP::Stager::MissingFrameworkPluginError
    end

    [framework_plugin, feature_plugins]
  end
end
