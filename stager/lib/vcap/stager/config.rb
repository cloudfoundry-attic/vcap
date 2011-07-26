require 'vcap/config'

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

      :redis => {
        :host                => String,
        optional(:port)      => Integer,
        optional(:password)  => String,
        optional(:namespace) => String,
      },

      :nats_uri              => String,     # NATS uri of the form nats://<user>:<pass>@<host>:<port>
      :max_staging_duration  => Integer,    # Maximum number of seconds a staging can run
      :queues                => [String],   # List of queues to pull tasks from
      :pid_filename          => String,     # Pid filename to use
      optional(:dirs) => {
        optional(:manifests) => String,     # Where all of the staging manifests live
        optional(:tmp)       => String,     # Default is /tmp
      },


      optional(:secure_user) => {           # Drop privs during staging to this user
        :uid                 => Integer,
        optional(:gid)       => Integer,
      },

      optional(:index)       => Integer,    # Component index (stager-0, stager-1, etc)
      optional(:ruby_path)   => String,     # Full path to the ruby executable that should execute the run plugin script
      optional(:local_route) => String,     # If set, use this to determine the IP address that is returned in discovery messages
      optional(:run_plugin_path) => String, # Full path to run plugin script
    }
  end

  def self.from_file(*args)
    config = super(*args)

    config[:dirs] ||= {}
    config[:dirs][:manifests] ||= File.expand_path('../plugin/manifests', __FILE__)
    config[:run_plugin_path]  ||= File.expand_path('../../../../bin/run_plugin', __FILE__)
    config[:ruby_path]        ||= `which ruby`.chomp

    config
  end
end
