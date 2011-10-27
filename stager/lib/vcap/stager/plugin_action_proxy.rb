module VCAP
  module Stager
  end
end

# This class exposes actions that modify VCAP resources to staging plugins. An instance
# of it is passed to the plugin as a parameter to the stage() method.
class VCAP::Stager::PluginActionProxy
  def initialize(start_script_path, stop_script_path, droplet)
    @start_script_path = start_script_path
    @start_script      = nil
    @stop_script_path  = stop_script_path
    @stop_script       = nil
    @droplet = droplet
  end

  # Creates a service on behalf of the user
  #
  # @param label        String  The label that uniquely identifies this service
  # @param name         String  What to call the provisioned service
  # @param plan         String  Which plan should be provisioned
  # @param plan_option  String  Optional plan option to select.
  def create_service(label, name, plan, plan_option=nil)
    raise NotImplementedError
  end

  # Binds a service to the application being staged
  #
  # @param name             String  Name of service to bind
  # @param binding_options  Hash    Service specific binding options
  def bind_service(name, binding_options)
    raise NotImplementedError
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
