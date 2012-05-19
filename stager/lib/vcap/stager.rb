require 'vcap/stager/constants'
require 'vcap/stager/config'
require 'vcap/stager/process_runner'
require 'vcap/stager/secure_user_manager'
require 'vcap/stager/server'
require 'vcap/stager/task'
require 'vcap/stager/task_error'
require 'vcap/stager/task_logger'
require 'vcap/stager/task_result'
require 'vcap/stager/version'
require 'vcap/stager/workspace'

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
      end
    end
  end
end
