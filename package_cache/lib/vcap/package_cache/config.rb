require 'vcap/config'

module VCAP module PackageCache end end

# Config template for stager
class VCAP::PackageCache::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path('../../../../config/dev.yml', __FILE__)

  define_schema do
    {
      optional(:listen_socket) => String,     # path to domain socket to listen on.
      optional(:listen_port)   => Integer,    # tcp port to listen on.
      :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },

      :base_dir              => String,     # where all package cache stuff lives.
      :pid_file              => String     # where our pid file lives.
    }
  end

  class << self
    def from_file(*args)
      config = super(*args)
      verify_config(config)
      config
    end

    private

    def verify_config(config)
      listen_socket = config[:listen_socket]
      listen_port = config[:listen_port]
      if listen_port and listen_socket
        raise "only one of :listen_socket or :listen_port should be set."
      end
      if (not listen_port) and (not listen_socket)
        raise "at least one of :listen_socket or :listen_port should be set."
      end

      base_dir = config[:base_dir]
      raise "base_dir: #{base_dir} does not exists." if not Dir.exists?(base_dir)

      log_level = config[:logging][:level]
      raise "invalid log level #{log_level}." if not %w[debug info warn error debug fatal].include?(log_level)
    end
  end
end
