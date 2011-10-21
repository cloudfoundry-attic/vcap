module VCAP
  module Stager
  end
end

# This class exposes actions that modify VCAP resources to staging plugins. An instance
# of it is passed to the plugin as a parameter to the stage() method.
class VCAP::Stager::PluginActionProxy
  attr_reader :services_client

  def initialize(start_script_path, stop_script_path, droplet, services_client)
    @start_script_path = start_script_path
    @start_script      = nil
    @stop_script_path  = stop_script_path
    @stop_script       = nil
    @droplet           = droplet
    @services_client   = services_client
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
