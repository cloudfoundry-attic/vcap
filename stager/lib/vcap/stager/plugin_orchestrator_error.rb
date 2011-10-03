module VCAP
  module Stager
    class PluginOrchestratorError       < StandardError; end
    class MissingFrameworkPluginError   < PluginOrchestratorError; end
    class DuplicateFrameworkPluginError < PluginOrchestratorError; end
    class UnknownPluginTypeError        < PluginOrchestratorError; end
  end
end
