require 'erb'
require 'fileutils'
require 'thread'
require 'yaml'

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
  class PluginLogger
    def initialize(plugin_name, io)
      @log_lock     = Mutex.new
      @logger       = Logger.new(io)
      @logger.level = Logger::DEBUG
      @logger.formatter = proc do |sev, time, progname, msg|
        "[#{plugin_name}] #{msg}\n"
      end
    end

    def method_missing(method, *args, &blk)
      @log_lock.synchronize do
        @logger.send(method, *args, &blk)
      end
    end
  end

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
  def initialize(plugins, opts={})
    @plugins  = plugins
    @log_path = opts[:log_path]
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
    environment = {}
    droplet     = VCAP::Stager::Droplet.new(dest_dir)
    logger      = make_plugin_logger('plugin_runner')

    framework_plugin, feature_plugins = collect_plugins(app_props)

    logger.info("Setting up base droplet structure")
    droplet.create_skeleton(source_dir)

    pname = framework_plugin.name
    actions = VCAP::Stager::PluginActionProxy.new(droplet.framework_start_path,
                                                  droplet.framework_stop_path,
                                                  droplet,
                                                  environment,
                                                  make_plugin_logger(pname))
    logger.info("Running framework plugin: #{framework_plugin.name}")
    framework_plugin.stage(droplet.app_source_dir, actions, app_props)

    for feature_plugin in feature_plugins
      pname = feature_plugin.name
      actions = VCAP::Stager::PluginActionProxy.new(droplet.feature_start_path(pname),
                                                    droplet.feature_stop_path(pname),
                                                    droplet,
                                                    environment,
                                                    make_plugin_logger(pname))
      logger.info("Running feature plugin: #{feature_plugin.name}")
      feature_plugin.stage(framework_plugin, droplet.app_source_dir, actions, app_props)
    end

    droplet.generate_vcap_start_script(environment)
  end

  # Returns the plugins that will be executed, in order.
  #
  # @param  [Hash]  app_props  Application properties
  #
  # @return [Array]            [framework_plugin, *feature_plugins]
  def collect_plugins(app_props)
    feature_plugins  = []
    framework_plugin = nil

    for name, plugin in @plugins

      next unless plugin.respond_to?(:should_stage?) && plugin.should_stage?(app_props)

      if plugin.framework_plugin?
        if framework_plugin
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

  def make_plugin_logger(plugin_name)
    if @log_path
      io = File.open(@log_path, 'a+')
    else
      io = STDOUT
    end
    PluginLogger.new(plugin_name, io)
  end
end
