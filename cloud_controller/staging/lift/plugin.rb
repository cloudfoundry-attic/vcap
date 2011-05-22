# Copyright (c) 2009-2011 VMware, Inc.
# Author: A.B.Srinivasan - asrinivasan@vmware.com

require File.expand_path('../../java_common/tomcat', __FILE__)

class LiftPlugin < StagingPlugin

  LIFT_FILTER_CLASS = 'net.liftweb.http.LiftFilter'
  CF_LIFT_PROPERTIES_GENERATOR_FILTER = 
    'CloudLiftServicesPropertiesGeneratorFilter'
  CF_LIFT_PROPERTIES_GENERATOR_FILTER_CLASS = 
    'org.cloudfoundry.reconfiguration.CloudLiftServicesPropertiesGeneratorFilter';

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
      configure_lift_filter webapp_root
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

  def configure_lift_filter webapp_path
    web_config_file = File.join(webapp_path, 'WEB-INF/web.xml')
    if File.exist? web_config_file
      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_filter = web_config.xpath("//web-app/filter[contains(
                                          normalize-space(#{prefix}filter-class),
                                          '#{LIFT_FILTER_CLASS}')]")
      unless lift_filter == nil || lift_filter.empty?
        cf_lift_props_generator_filter = generate_cf_filter web_config
        lift_filter.first.add_previous_sibling cf_lift_props_generator_filter
        lift_filter_name = lift_filter.first.xpath("#{prefix}filter-name").first.content
        lift_filter_map = web_config.xpath("//web-app/filter-mapping[contains(
                                           normalize-space(#{prefix}filter-name),
                                           normalize-space(#{lift_filter_name}))]")
        cf_lift_props_generator_filter_map = 
          generate_cf_filter_map web_config, lift_filter_map, prefix
        lift_filter_map.first.add_previous_sibling cf_lift_props_generator_filter_map
        File.open(web_config_file, 'w') {|f| f.write(web_config.to_xml) }
      else
        raise "Scala / Lift application staging failed: no LiftFilter class found in web.xml"
      end
    else
      raise "Scala / Lift application staging failed: web.xml not found"
    end
  end

  def generate_cf_filter web_config
    cf_lift_props_generator_filter = Nokogiri::XML::Node.new 'filter', web_config

    cf_filter_name = Nokogiri::XML::Node.new 'filter-name', web_config
    cf_filter_name.content = CF_LIFT_PROPERTIES_GENERATOR_FILTER

    cf_filter_class = Nokogiri::XML::Node.new 'filter-class', web_config
    cf_filter_class.content = CF_LIFT_PROPERTIES_GENERATOR_FILTER_CLASS

    cf_filter_description = Nokogiri::XML::Node.new 'description', web_config
    cf_filter_description.content = 
      "A filter that generates a properties file with CloudFoundry services information"

    cf_lift_props_generator_filter.add_child cf_filter_name
    cf_lift_props_generator_filter.add_child cf_filter_class
    cf_lift_props_generator_filter.add_child cf_filter_description

    cf_lift_props_generator_filter
  end

  def generate_cf_filter_map web_config, lift_filter_map, prefix
    url_pattern = lift_filter_map.xpath("url-pattern").first.content

    cf_lift_props_generator_filter_map = 
      Nokogiri::XML::Node.new 'filter-mapping', web_config

    cf_filter_map_name = Nokogiri::XML::Node.new 'filter-name', web_config
    cf_filter_map_name.content = CF_LIFT_PROPERTIES_GENERATOR_FILTER

    cf_filter_url = Nokogiri::XML::Node.new 'url-pattern', web_config
    cf_filter_url.content = url_pattern

    cf_lift_props_generator_filter_map.add_child cf_filter_map_name
    cf_lift_props_generator_filter_map.add_child cf_filter_url

    cf_lift_props_generator_filter_map
  end

end
