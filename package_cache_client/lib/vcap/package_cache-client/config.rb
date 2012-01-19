require 'vcap/config'
require 'vcap/json_schema'

module VCAP module PackageCacheClient end end

# Config template for stager
class VCAP::PackageCacheClient::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path('../../../../config/client_dev.yml', __FILE__)

  define_schema do
    {
      :listen_port         => Integer,    # tcp port to listen on.
      :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },
      :base_dir              => String,     # where all package cache stuff lives.
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
      log_level = config[:logging][:level]
      raise "invalid log level #{log_level}." unless %w[debug info warn error debug fatal].include?(log_level)

      base_dir = config[:base_dir]
      raise "invalid base_dir" unless Dir.exists?(base_dir)
    end
  end
end
