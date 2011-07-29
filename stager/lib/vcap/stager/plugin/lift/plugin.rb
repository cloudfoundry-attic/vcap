# Copyright (c) 2009-2011 VMware, Inc.
# Author: A.B.Srinivasan - asrinivasan@vmware.com

require File.expand_path('../../java_common/tomcat', __FILE__)

class LiftPlugin < StagingPlugin

  LIFT_FILTER_CLASS = 'net.liftweb.http.LiftFilter'
  CF_LIFT_PROPERTIES_GENERATOR_CLASS =
    'org.cloudfoundry.reconfiguration.CloudLiftServicesPropertiesGenerator';

  def framework
    'lift'
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
      configure_cf_lift_servlet_context_listener(webapp_root)
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
      <<-LIFT
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
      LIFT
    end
  end

  # We introspect the web configuration ('WEB-INF/web.xml' file) and
  # if we find a LiftFilter node, we add a ServletContextListener
  # before any servlet and filter nodes.
  # The added ServletContextListener is responsible for generating a properties
  # file that is consulted by the Lift framework to determine the binding
  # information of the services used by the application.
  def configure_cf_lift_servlet_context_listener(webapp_path)
    web_config_file = File.join(webapp_path, 'WEB-INF/web.xml')
    if File.exist? web_config_file
      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_filter = web_config.xpath("//web-app/filter[contains(
                                          normalize-space(#{prefix}filter-class),
                                          '#{LIFT_FILTER_CLASS}')]")
      unless lift_filter == nil || lift_filter.empty?
        servlet_node =  web_config.xpath("//web-app/servlet")
        if servlet_node == nil || servlet_node.empty?
          target_node = lift_filter.first
        else
          target_node = servlet_node.first
        end
        servlet_context_listener = generate_cf_servlet_context_listener(web_config)
        target_node.add_previous_sibling(servlet_context_listener)
        File.open(web_config_file, 'w') {|f| f.write(web_config.to_xml) }
      else
        raise "Scala / Lift application staging failed: no LiftFilter class found in web.xml"
      end
    else
      raise "Scala / Lift application staging failed: web.xml not found"
    end
  end

  def generate_cf_servlet_context_listener(web_config)
    cf_servlet_context_listener = Nokogiri::XML::Node.new('listener', web_config)

    cf_servlet_context_listener_class = Nokogiri::XML::Node.new('listener-class', web_config)
    cf_servlet_context_listener_class.content = CF_LIFT_PROPERTIES_GENERATOR_CLASS

    cf_servlet_context_listener.add_child(cf_servlet_context_listener_class)

    cf_servlet_context_listener
  end

end
