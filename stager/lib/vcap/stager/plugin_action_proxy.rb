module VCAP
  module Stager
  end
end

# This class exposes actions that modify VCAP resources to staging plugins. An instance
# of it is passed to the plugin as a parameter to the stage() method.
class VCAP::Stager::PluginActionProxy
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
    raise NotImplementedError
  end

  # Returns an open file object that the user can write contents of a stop
  # script into.
  #
  # @return File
  def stop_script
    raise NotImplementedError
  end
end
