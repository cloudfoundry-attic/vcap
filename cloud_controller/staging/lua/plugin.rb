class LuaPlugin < StagingPlugin
  def framework
    'lua'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  def start_command
    "wsapi -c ./cnf/wsapi.conf"
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars) do
      plugin_specific_startup
    end
  end

  def plugin_specific_startup
    cmds = []
    cmds << "mkdir cnf"
    cmds << 'echo "port = os.getenv(\'VMC_APP_PORT\')" >> ./cnf/wsapi.conf'
    cmds.join("\n")
  end

end