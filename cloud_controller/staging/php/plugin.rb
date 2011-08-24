require File.expand_path('../../apache_common/apache', __FILE__)

class PhpPlugin < StagingPlugin
  def framework
    'php'
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      Apache.prepare(destination_directory)
      copy_source_files
      create_startup_script
    end
  end

  # The Apache start script runs from the root of the staged application.
  def change_directory_for_start
    "cd apache"
  end

  def start_command
    "bash ./start.sh"
  end

  private

  def startup_script
    vars = environment_hash
    generate_startup_script(vars) do
      <<-PHPEOF
env > env.log
ruby resources/generate_apache_conf $VCAP_APP_PORT $HOME $VCAP_SERVICES #{application_memory}m
      PHPEOF
    end
  end

  def apache_server_root
    File.join(destination_directory, 'apache')
  end
end