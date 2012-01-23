require 'vcap/stager/errors'

module VCAP
  module Stager
  end
end

# This class exposes actions that modify VCAP resources to staging plugins. An instance
# of it is passed to the plugin as a parameter to the stage() method.
class VCAP::Stager::PluginActionProxy
  attr_reader :services_client

  # Consumers of a PluginActionProxy can set and inspect environment variables via
  # this hash. Settings here will persist across all calls to feature/framework start
  # scripts and into the started application's environment.
  #
  # NB: Consumers MUST escape and quote their environment variables properly. We could
  #     attempt to escape and quote them ourselves, but since we cannot know the intent
  #     of the consumer, this would ultimately end in failure. Consider the following
  #     example:
  #
  #         actions.environment['HI'] = "Hello $USER"
  #
  #     Is the intent here to employ variable substitution or to use the literal
  #     string '$USER'?
  attr_accessor :environment

  def initialize(start_script_path, stop_script_path, droplet, env)
    @start_script_path = start_script_path
    @start_script      = nil
    @stop_script_path  = stop_script_path
    @stop_script       = nil
    @droplet           = droplet
    @environment       = env
  end

  # Returns an open file object that the user can write contents of a
  # start script into.
  #
  # @return File
  def start_script
    @start_script ||= create_script(@start_script_path)
    @start_script
  end

  # Returns an open file object that the user can write contents of a stop
  # script into.
  #
  # @return File
  def stop_script
    @stop_script ||= create_script(@stop_script_path)
    @stop_script
  end

  # Returns the path to the base of the droplet directory.
  #
  # @return String
  def droplet_base_dir
    @droplet.base_dir
  end

  private

  def create_script(path)
    ret = File.new(path, 'w+')
    FileUtils.chmod(0755, path)
    ret
  end
end
