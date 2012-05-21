class PlayPlugin < StagingPlugin

  include JavaDatabaseSupport
  include JavaAutoconfig

  def framework
    'play'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      FileUtils.chmod(0744, @destination_directory + '/app/start')
      services = environment[:services] if environment
      copy_service_drivers destination_directory + '/app/lib', services
      configure_autostaging
      create_startup_script
      create_stop_script
    end
  end

  def configure_autostaging
    copy_autostaging_jar destination_directory + '/app/lib'
    # Replace the main Play class with our autostaging class
    play_start_script = destination_directory + '/app/start'
    start_cmd = File.read play_start_script
    File.open(play_start_script, "w") do |file|
      file.write start_cmd.gsub(/play\.core\.server\.NettyServer/, "org.cloudfoundry.reconfiguration.play.Bootstrap")
    end
  end

  def copy_source_files(dest = nil)
    Dir.chdir(source_directory) do
      dest ||= File.join(@destination_directory, 'app')
      # Play dists unpack to a dir named for app.  Assume that is the only entry
      app_dir = File.join(@source_directory,Dir.glob("*").first)
      system "cp -a #{File.join(app_dir, "*")} #{dest}"
    end
  end

  def start_command
    "./start -Xms#{application_memory}m -Xmx#{application_memory}m -Dhttp.port=$VCAP_APP_PORT $JAVA_OPTS"
  end

  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end
end
