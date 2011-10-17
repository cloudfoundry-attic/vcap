require 'vcap/stager/app_properties'
require 'vcap/stager/constants'
require 'vcap/stager/config'
require 'vcap/stager/plugin_action_proxy'
require 'vcap/stager/plugin_orchestrator'
require 'vcap/stager/plugin_orchestrator_error'
require 'vcap/stager/plugin_registry'
require 'vcap/stager/task'
require 'vcap/stager/task_error'
require 'vcap/stager/task_logger'
require 'vcap/stager/task_manager'
require 'vcap/stager/server'
require 'vcap/stager/util'
require 'vcap/stager/version'

module VCAP
  module Stager
    class << self
      attr_accessor :config

      def init(config)
        @config = config
        VCAP::Logging.setup_from_config(config[:logging])
        StagingPlugin.manifest_root = config[:dirs][:manifests]
        StagingPlugin.load_all_manifests
        StagingPlugin.validate_configuration!
        VCAP::Stager::Task.set_defaults(config)
        VCAP::Stager::Task.set_defaults({:manifest_dir => config[:dirs][:manifests]})
      end
    end
  end
end
