class DotNetPlugin < StagingPlugin
  require "json"

  def framework
    'dotNet'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  def generate_startup_script(env_vars = {})
    plugin_staging_info = Hash.new
    plugin_staging_info[:assembly] = "Uhuru.CloudFoundry.DEA.Plugins.dll"
    plugin_staging_info[:class_name] = "Uhuru.CloudFoundry.DEA.Plugins.IISPlugin"
    plugin_staging_info[:logs] = Hash.new
    plugin_staging_info[:logs][:app_error] = "logs/stderr.log"
    plugin_staging_info[:logs][:dea_error] = "logs/err.log"
    plugin_staging_info[:logs][:startup] = "logs/startup.log"
    plugin_staging_info[:logs][:app] = "logs/stdout.log"
    plugin_staging_info.to_json
  end

  private

  def startup_script
    vars = environment_hash
    generate_startup_script(vars)  
  end

end

