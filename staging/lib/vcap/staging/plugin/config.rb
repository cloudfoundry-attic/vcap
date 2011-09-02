require 'vcap/config'

class StagingPlugin
end

class StagingPlugin::Config < VCAP::Config
  define_schema do
    { :source_dir             => String,        # Location of the unstaged app
      :dest_dir               => String,        # Where to place the staged app
      optional(:manifest_dir) => String,

      optional(:secure_user) => {               # Drop privs to this user
        :uid           => Integer,
        optional(:gid) => Integer,
      },

      optional(:environment) => {               # This is misnamed, but it is called this
        :services  => [Hash],                   # throughout the existing staging code. We use
        :framework => String,                   # it to maintain consistency.
        :runtime   => String,
        :resources => {
          :memory => Integer,
          :disk   => Integer,
          :fds    => Integer,
        }
      },
    }
  end

  def self.from_file(*args)
    config = super(*args)

    # Support code expects symbolized keys for service information
    config[:environment][:services] = config[:environment][:services].map {|svc| VCAP.symbolize_keys(svc) } if config[:environment]


    config
  end
end
