class ErlangPlugin < StagingPlugin
  # TODO - Is there a way to avoid this without some kind of 'register' callback?
  # e.g. StagingPlugin.register('sinatra', __FILE__)
  def framework
    'erlang'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  # Let DEA fill in as needed..
  def start_command
    "%VCAP_LOCAL_RUNTIME% -pa ebin edit deps/*/ebin -boot start_sasl +B -noinput -s #{detect_app_name}  $@"
  end

  private
  def startup_script
    vars = environment_hash
    generate_startup_script(vars)
  end

  # Detect the name of the application by looking for .app files in ebin.
  def detect_app_name
    file, app_files = nil, app_files_matching_patterns

    if app_files.length == 1
      file = File.basename(app_files.first)[0..-5]    # Remove the .app suffix
    else
      raise "Multiple Erlang .app files found. Cannot start application."
    end

    # TODO - Currently staging exceptions are not handled well.
    # Convert to using exit status and return value on a case-by-case basis.
    raise "Unable to determine Erlang startup command" unless file
    file
  end
end

