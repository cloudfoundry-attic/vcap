require File.expand_path('../../java_common/tomcat', __FILE__)

class SpringPlugin < StagingPlugin
  def framework
    'spring'
  end

  def autostaging_template
    File.join(File.dirname(__FILE__), '../java_common/resources', 'autostaging_template_spring.xml')
  end

  def skip_staging webapp_root
    false
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      webapp_root = Tomcat.prepare(destination_directory)
      copy_source_files(webapp_root)
      Tomcat.configure_tomcat_application(destination_directory, webapp_root, self.autostaging_template, environment)  unless self.skip_staging(webapp_root)
      create_startup_script
    end
  end

  def create_app_directories
    FileUtils.mkdir_p File.join(destination_directory, 'logs')
  end

  # The Tomcat start script runs from the root of the staged application.
  def change_directory_for_start
    "cd tomcat"
  end

  # We redefine this here because Tomcat doesn't want to be passed the cmdline
  # args that were given to the 'start' script.
  def start_command
    "./bin/catalina.sh run"
  end

  def configure_catalina_opts
    # We want to set this to what the user requests, *not* set a minum bar
    "-Xms#{application_memory}m -Xmx#{application_memory}m"
  end

  private
  def startup_script
    vars = environment_hash
    vars['CATALINA_OPTS'] = configure_catalina_opts
    generate_startup_script(vars) do
      <<-SPRING
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
env > env.log
PORT=-1
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
  esac
done
if [ $PORT -lt 0 ] ; then
  echo "Missing or invalid port (-p)"
  exit 1
fi
ruby resources/generate_server_xml $PORT
      SPRING
    end
  end
end
