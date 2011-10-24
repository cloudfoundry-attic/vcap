module VCAP
  module Stager
    class PluginRunnerError       < StandardError; end
    class MissingFrameworkPluginError   < PluginRunnerError; end
    class DuplicateFrameworkPluginError < PluginRunnerError; end
    class UnknownPluginTypeError        < PluginRunnerError; end
  end
end
