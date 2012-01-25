require 'vcap/config'
require 'vcap/json_schema'

module VCAP module PackageCache end end

# Config template for stager
class VCAP::PackageCache::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path('../../../../config/package_cache.yml', __FILE__)

  define_schema do
    {
      :listen_port         => Integer,    # tcp port to listen on.
      :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },

      :base_dir              => String,     # where all package cache stuff lives.
      :pid_filename          => String,     # where our pid file lives.
      :purge_cache_on_startup => VCAP::JsonSchema::BoolSchema.new,     # true/false, blow away cache or not.
      :runtimes => {
        :gem => {
          optional(:ruby18)   => String,      # path to ruby 1.8 executable.
          optional(:ruby19)   => String,      # path to ruby 1.9 executable.
        },
      },

    }
  end

  class << self
    def from_file(*args)
      config = super(*args)
      normalize_config(config)
      config
    end

    private

    def normalize_config(config)
      config[:runtimes].each { |k,v|
        path = v.values[0]
        raise "Invalid runtime #{path}." if not File.executable?(path)
      }

      log_level = config[:logging][:level]
      raise "invalid log level #{log_level}." if not %w[debug info warn error debug fatal].include?(log_level)
    end
  end
end
