module VCAP
  module Stager
    module PluginRunner
    end
  end
end

class VCAP::Stager::PluginRunner::Base
  # Stages the application located at src_path into the directory located at
  # dst_path
  #
  # @param [Hash] properties  Application properties. Includes framework,
  #                           runtimes, services, etc.
  # @param [String] src_path
  # @param [String] dst_path
  #
  # @return [Hash]  :log   => Staging log
  #                 :error => String description of the error that occurred.
  def stage(properties, src_path, dst_path)
    raise NotImplementedError
  end
end
