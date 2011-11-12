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
    # Writes out necessary information for invoking the plugin runner using
    # the standalone script.
    #
    # @param task_path  String  Where to serialize the task
    # @param opts       Hash    'error_path' => Where to store any exceptions
    #                                           thrown during the process.
    #                           'config_dir' => Optional. Directory containing
    #                                           config files for staging plugins.
    #                           'log_path'   => Optional. Where to log plugin output.
    #                                           If not provided, logs will go to stdout.
    def serialize_task(task_path, source_dir, dest_dir, app_props, cc_info, opts={})
      task = {
        'source_dir' => source_dir,
        'dest_dir'   => dest_dir,
        'app_props'  => app_props,
        'cc_info'    => cc_info,
        'opts'       => opts,
      }
      File.open(task_path, 'w+') do |f|
        YAML.dump(task, f)
      end
    end

    def deserialize_task(task_path)
      YAML.load_file(task_path)
    end
  end

  # @param plugins  Array    Available plugins
  #                          name => plugin
  def initialize(plugins={})
    @plugins = plugins
  end

  # Runs the appropriate plugins to stage the given application
  #
  # @param source_dir  String  Directory containing application source
  # @param dest_dir    String  Directory where the staged droplet should live
  # @param app_props   Hash    Application properties.
  # @param cc_info     Hash    Information needed for contacting the CC
  #                              'host'
  #                              'port'
  #                              'task_id'
  def run_plugins(source_dir, dest_dir, app_props, cc_info)
    environment     = {}
    droplet         = VCAP::Stager::Droplet.new(dest_dir)
    services_client = VCAP::CloudController::Ipc::ServiceConsumerV1Client.new(cc_info['host'],
                                                                              cc_info['port'],
                                                                              :staging_task_id => cc_info['task_id'])
    logger = VCAP::Logging.logger('vcap.stager.plugin_runner')

    framework_plugin, feature_plugins = collect_plugins(app_props['framework'], app_props['plugins'].keys)

    logger.info("Setting up base droplet structure")
    droplet.create_skeleton(source_dir)

    actions = VCAP::Stager::PluginActionProxy.new(droplet.framework_start_path,
                                                  droplet.framework_stop_path,
                                                  droplet,
                                                  services_client,
                                                  environment)
    logger.info("Running framework plugin: #{framework_plugin.name}")
    framework_plugin.stage(droplet.app_source_dir, actions, app_props)

    for feature_plugin in feature_plugins
      pname = feature_plugin.name
      actions = VCAP::Stager::PluginActionProxy.new(droplet.feature_start_path(pname),
                                                    droplet.feature_stop_path(pname),
                                                    droplet,
                                                    services_client,
                                                    environment)
      logger.info("Running feature plugin: #{feature_plugin.name}")
      feature_plugin.stage(framework_plugin, droplet.app_source_dir, actions, app_props)
    end

    droplet.generate_vcap_start_script(environment)
  end

  # Returns the plugins that will be executed, in order.
  #
  # @param  framework  String         Framework of the application being staged
  # @param  plugins    Array[String]  List of plugin names
  #
  # @return Array                     [framework_plugin, *feature_plugins]
  def collect_plugins(framework, plugins)
    feature_plugins  = []
    framework_plugin = nil

    for name in plugins
      plugin = @plugins[name]
      unless plugin || plugin.respond_to?(:stage)
        raise VCAP::Stager::UnsupportedPluginError, name
      end

      if plugin.respond_to?(:framework)
        if plugin.framework != framework
          raise VCAP::Stager::DuplicateFrameworkPluginError, plugin.name
        else
          framework_plugin = plugin
        end
      else
        feature_plugins << plugin
      end
    end

    unless framework_plugin
      raise VCAP::Stager::MissingFrameworkPluginError
    end

    [framework_plugin, feature_plugins]
  end
end
