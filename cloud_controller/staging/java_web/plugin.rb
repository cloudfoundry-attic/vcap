require File.expand_path('../../common', __FILE__)
require File.join(File.expand_path('../', __FILE__), 'tomcat.rb')

class JavaWebPlugin < StagingPlugin
  def framework
    'java_web'
  end

  def autostaging_template
    nil
  end

  def skip_staging webapp_root
    true
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      webapp_root = Tomcat.prepare(destination_directory)
      copy_source_files(webapp_root)
      web_config_file = File.join(webapp_root, 'WEB-INF/web.xml')
      unless File.exist? web_config_file
        raise "Web application staging failed: web.xml not found"
      end
      do_pre_tomcat_config_setup(webapp_root)
      Tomcat.configure_tomcat_application(destination_directory, webapp_root, self.autostaging_template, environment)  unless self.skip_staging(webapp_root)
      create_startup_script
    end
  end

  def do_pre_tomcat_config_setup webapp_path
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
      <<-JAVA
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
env > env.log
ruby resources/generate_server_xml $BACKEND_PORT
      JAVA
    end
  end
end
