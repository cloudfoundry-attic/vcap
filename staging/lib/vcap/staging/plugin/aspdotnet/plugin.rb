class AspdotnetPlugin < StagingPlugin

  def framework
    'aspdotnet'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
    end
  end

  def start_command
    # No start command for ASP.NET apps.
  end
end
