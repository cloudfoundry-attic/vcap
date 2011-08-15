require 'eventmachine'
require 'resque'

require 'vcap/stager/errors'
require 'vcap/stager/config'
require 'vcap/stager/plugin'
require 'vcap/stager/task'
require 'vcap/stager/task_logger'
require 'vcap/stager/task_result'
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

        Resque.redis = Redis.new(config[:redis])
        Resque.redis.namespace = config[:redis][:namespace] if config[:redis][:namespace]
        # Prevents EM from getting into a blind/deaf state after forking.
        # See: https://github.com/eventmachine/eventmachine/issues/213
        Resque.after_fork do |job|
          if EM.reactor_running?
            EM.stop_event_loop
            EM.release_machine
            EM.instance_variable_set('@reactor_running', false)
          end
        end
      end
    end
  end
end
