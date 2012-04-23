# Copyright (c) 2009-2011 VMware, Inc.
# Copyright (c) 2011 Uhuru Software, Inc., All Rights Reserved
class DotNetPlugin < StagingPlugin
  def framework
    'dotNet'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      copy_dea_plugin_assembly
      create_startup_script
    end
  end

  def generate_startup_script(env_vars = {})
    after_env_before_script = block_given? ? yield : "\n"
    #todo: vladi: VMC_APP_NAME is deprecated, this should be replaced with the proper VCAP env variable
    template = <<-SCRIPT
    <%= after_env_before_script %>
    Uhuru.CloudFoundry.DEA.Plugins.dll
    Uhuru.CloudFoundry.DEA.Plugins.IISPlugin
    SCRIPT
    ERB.new(template).result(binding).lines.reject {|l| l =~ /^\s*$/}.join
  end

  private

  def copy_dea_plugin_assembly

  end

  def startup_script
    vars = environment_hash
    generate_startup_script(vars)  
  end

end

