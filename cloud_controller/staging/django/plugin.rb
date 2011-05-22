class DjangoPlugin < StagingPlugin
  include VirtualenvSupport
  include PipSupport

  REQUIREMENTS = ['django', 'spawning']

  def framework
    'django'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
    end
  end

  def start_command
    cmds = []
    cmds << "source ../env/bin/activate"
    if uses_pip?
      cmds << install_requirements
    end
    cmds << "spawning --factory=spawning.django_factory.config_factory settings $@"
    cmds.join("\n")
  end

  private

  def startup_script
    vars = environment_hash
    generate_startup_script(vars) do
      setup_virtualenv(REQUIREMENTS)
    end
  end
end
