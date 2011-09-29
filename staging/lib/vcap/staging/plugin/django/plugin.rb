class DjangoPlugin < StagingPlugin
  include PipSupport

  REQUIREMENTS = ['django', 'gunicorn']

  def framework
    'django'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      copy_source_files
      create_startup_script
      create_stop_script
      create_gunicorn_config
    end
  end

  def start_command
    cmds = []
    if uses_pip?
      cmds << install_requirements
    end
    cmds << "python manage.py syncdb --noinput >> ../logs/startup.log 2>&1"
    cmds << "../python/bin/gunicorn_django -c ../gunicorn.config"
    cmds.join("\n")
  end

  private

  def startup_script
    vars = environment_hash
    generate_startup_script(vars) do
      setup_python_env(REQUIREMENTS)
    end
  end

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end

  def create_gunicorn_config
    File.open('gunicorn.config', 'w') do |f|
      f.write <<-EOT
import os
bind = "0.0.0.0:%s" % os.environ['VCAP_APP_PORT']
loglevel = "debug"
      EOT
    end
  end
end
