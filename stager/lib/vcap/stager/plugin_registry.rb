module VCAP
  module Stager
  end
end

# This is a simple container class for all plugins that should be invoked during
# staging. The contract between the stager and plugins is simple:
#
# A staging plugin MUST call VCAP::Stager::PluginRegistry.register_plugin() with
# an instance of itself when it is required.
class VCAP::Stager::PluginRegistry
  class << self
    def method_missing(method, *args, &block)
      @registry ||= VCAP::Stager::PluginRegistry.new
      @registry.send(method, *args, &block)
    end
  end

  def initialize
    @plugins = []
  end

  attr_reader :plugins

  # Registers a plugin to be invoked during staging.
  #
  # @param  Object  Instance of a class implementing the staging plugin interface
  def register_plugin(plugin)
    @plugins << plugin
  end

  def reset
    @plugins = []
  end
end
