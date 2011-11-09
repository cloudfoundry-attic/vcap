require File.expand_path('../../common', __FILE__)

class JavaPlugin < StagingPlugin

  def framework
    'java'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      #TODO this is temporary.  Need a proper way to add executable perms
      FileUtils.chmod_R(0744, File.join(destination_directory, 'app'))
      create_startup_script
    end
  end

  private
  def start_command
    cmd = @environment[:meta][:command]
    if cmd.start_with?("java")
       cmd = cmd.sub(/java/, "java $JAVA_OPTS")
    end
    cmd
  end

  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end
end
