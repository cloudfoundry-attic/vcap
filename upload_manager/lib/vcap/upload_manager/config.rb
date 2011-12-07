require 'vcap/config'

module VCAP module UploadManager end end

# Config template for stager
class VCAP::UploadManager::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path('../../../../config/dev.yml', __FILE__)

  define_schema do
    {
      :listen_port         => Integer,    # tcp port to listen on.
      :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },

      :base_dir              => String,     # where we stash our stuff
      :pid_file              => String,     # where our pid file lives.
      :purge_resource_pool_on_startup => String  # useful for development/test
    }
  end

  class << self
    def from_file(*args)
      config = super(*args)
      normalize_config(config)
      config
    end

    private

    def to_boolean(field_name, str)
      if /true/.match(str) != nil
        true
      elsif /false$/.match(str) != nil
        false
      else
        raise "invalid config file entry #{field_name}, expected true or false"
      end
    end

    def normalize_config(config)
      base_dir = config[:base_dir]
      raise "base_dir: #{base_dir} does not exists." if not Dir.exists?(base_dir)

      log_level = config[:logging][:level]
      raise "invalid log level #{log_level}." if not %w[debug info warn error debug fatal].include?(log_level)

      config[:purge_resource_pool_on_startup] = to_boolean(:purge_resource_pool_on_startup.to_s, config[:purge_resource_pool_on_startup])
    end
  end
end
