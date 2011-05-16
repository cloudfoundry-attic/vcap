class LuajitPlugin < StagingPlugin
  def framework
    'luajit'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  def start_command
    "/usr/local/bin/wsapi -p $VCAP_APP_PORT"
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

end