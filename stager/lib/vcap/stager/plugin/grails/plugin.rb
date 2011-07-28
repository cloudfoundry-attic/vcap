require 'nokogiri'

require File.expand_path('../../java_common/tomcat', __FILE__)

class GrailsPlugin < StagingPlugin
  VMC_GRAILS_PLUGIN = "CloudFoundryGrailsPlugin"
  def framework
    'grails'
  end

  def autostaging_template
    File.join(File.dirname(__FILE__), '../java_common/resources', 'autostaging_template_grails.xml')
  end

  # Staging is skipped if the Grails configuration in ""WEB-INF/grails.xml" contains
  # a reference to "VmcGrailsPlugin"
  def skip_staging webapp_root
    skip = false
    grails_config_file = File.join(webapp_root, 'WEB-INF/grails.xml')
    if File.exist? grails_config_file
      skip = self.vmc_plugin_present grails_config_file
    end
    skip
  end

  def vmc_plugin_present grails_config_file
    grails_config = Nokogiri::XML(open(grails_config_file))
    prefix = grails_config.root.namespace ? "xmlns:" : ''
    plugins = grails_config.xpath("//#{prefix}plugins/#{prefix}plugin[contains(normalize-space(), '#{VMC_GRAILS_PLUGIN}')]")
    if (plugins == nil || plugins.empty?)
      return false
    end
    true
  end

  def stage_application
    Dir.chdir(destination_directory) do
      create_app_directories
      webapp_root = Tomcat.prepare(destination_directory)
      copy_source_files(webapp_root)
      Tomcat.configure_tomcat_application(destination_directory, webapp_root, self.autostaging_template, environment) unless self.skip_staging(webapp_root)
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
      <<-GRAILS
export CATALINA_OPTS="$CATALINA_OPTS `ruby resources/set_environment`"
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
      GRAILS
    end
  end
end
