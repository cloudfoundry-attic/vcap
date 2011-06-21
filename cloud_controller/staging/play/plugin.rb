class PlayPlugin < StagingPlugin
  # TODO - Is there a way to avoid this without some kind of 'register' callback?
  # e.g. StagingPlugin.register('sinatra', __FILE__)
  def framework
    'play'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  def start_command
    "/opt/play/play run . --%cloud --http.port=$VCAP_APP_PORT --pid_file=../run.pid "
  end

  def start_script_template
    <<-SCRIPT
STARTED=$!
    SCRIPT
  end

  def stop_script_template
    <<-SCRIPT
#!/bin/bash
kill -9 $STARTED
kill -9 $PPID
    SCRIPT
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end
end
