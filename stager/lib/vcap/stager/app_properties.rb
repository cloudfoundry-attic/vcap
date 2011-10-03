require 'yajl'

require 'vcap/json_schema'

module VCAP
  module Stager
  end
end

class VCAP::Stager::AppProperties
  SCHEMA = VCAP::JsonSchema.build do
    { :name        => String,
      :framework   => String,
      :runtime     => String,
      :plugins     => Hash,
      :environment => Hash,
      :resource_limits => {
        :memory => Integer,
        :disk   => Integer,
        :fds    => Integer,
      },
      :service_bindings => Array,
    }
  end

  class << self
    def decode(enc)
      dec = Yajl::Parser.parse(enc, :symbolize_keys => true)
      SCHEMA.validate(dec)
      VCAP::Stager::AppProperties.new(dec[:name],
                                      dec[:framework],
                                      dec[:runtime],
                                      dec[:plugins],
                                      dec[:environment],
                                      dec[:resource_limits],
                                      dec[:service_bindings])
    end
  end

  attr_accessor :name
  attr_accessor :framework
  attr_accessor :runtime
  attr_accessor :plugins
  attr_accessor :environment
  attr_accessor :resource_limits
  attr_accessor :service_bindings

  def initialize(name, framework, runtime, plugins, environment, resource_limits, service_bindings)
    @name        = name
    @framework   = framework
    @runtime     = runtime
    @plugins     = plugins
    @environment = environment
    @resource_limits  = resource_limits
    @service_bindings = service_bindings
  end

  def encode
    h = {
      :name        => @name,
      :framework   => @framework,
      :runtime     => @runtime,
      :plugins     => @plugins,
      :environment => @environment,
      :resource_limits  => @resource_limits,
      :service_bindings => @service_bindings,
    }
    Yajl::Encoder.encode(h)
  end

end
