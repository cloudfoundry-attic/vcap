require File.expand_path('../../apache_common/apache', __FILE__)

class PhpPlugin < StagingPlugin
  def framework
    'php'
  end

  def resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      Apache.prepare(destination_directory)
      system "cp -a #{File.join(resource_dir, "conf.d", "*")} apache/php"
      copy_source_files
      create_startup_script
      create_stop_script
    end
  end

  # The Apache start script runs from the root of the staged application.
  def change_directory_for_start
    "cd apache"
  end

  def start_command
    "bash ./start.sh"
  end

  def stop_command
    cmds = []
    cmds << "CHILDPIDS=$(pgrep -P ${1} -d ' ')"
    cmds << "kill -9 ${1}"
    cmds << "for CPID in ${CHILDPIDS};do"
    cmds << "  kill -9 ${CPID}"
    cmds << "done"
    cmds.join("\n")
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

  def stop_script
    vars = environment_hash
    generate_stop_script(vars)
  end

  def apache_server_root
    File.join(destination_directory, 'apache')
  end
end
