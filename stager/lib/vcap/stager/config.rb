require 'vcap/config'
require 'vcap/json_schema'
require 'vcap/staging/plugin/common'

module VCAP
  module Stager
  end
end

# Config template for stager
class VCAP::Stager::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path('../../../../config/dev.yml', __FILE__)

  define_schema do
    { :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },

      :nats_uri              => String,     # NATS uri of the form nats://<user>:<pass>@<host>:<port>
      :max_staging_duration  => Integer,    # Maximum number of seconds a staging can run
      :max_active_tasks      => Integer,    # Maximum number of tasks executing concurrently
      :queues                => [String],   # List of queues to pull tasks from
      :pid_filename          => String,     # Pid filename to use

      optional(:tmpdir)      => String,
      optional(:index)       => Integer,    # Component index (stager-0, stager-1, etc)
      optional(:local_route) => String,     # If set, use this to determine the IP address that is returned in discovery messages

      :plugin_runner => {
        :type   => String, # Must be one of {"warden", "user"}
        :config => Hash,   # Plugin specific config. See plugin impls for more.
      }
    }
  end
end
