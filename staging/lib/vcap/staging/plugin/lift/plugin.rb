# Copyright (c) 2009-2011 VMware, Inc.
# Author: A.B.Srinivasan - asrinivasan@vmware.com

require File.join(File.expand_path('../../java_web', __FILE__), 'plugin.rb')

class LiftPlugin < JavaWebPlugin

  LIFT_FILTER_CLASS = 'net.liftweb.http.LiftFilter'
  CF_LIFT_PROPERTIES_GENERATOR_CLASS =
    'org.cloudfoundry.reconfiguration.CloudLiftServicesPropertiesGenerator';

  def framework
    'lift'
  end

  def autostaging_template
    nil
  end

  def skip_staging webapp_root
    false
  end

  def configure_webapp webapp_path, autostaging_template, environment
    configure_cf_lift_servlet_context_listener(webapp_path)
    copy_autostaging_jar File.join(webapp_path, 'WEB-INF/lib')
  end

  # We introspect the web configuration ('WEB-INF/web.xml' file) and
  # if we find a LiftFilter node, we add a ServletContextListener
  # before any servlet and filter nodes.
  # The added ServletContextListener is responsible for generating a properties
  # file that is consulted by the Lift framework to determine the binding
  # information of the services used by the application.
  def configure_cf_lift_servlet_context_listener(webapp_path)
    web_config = Tomcat.get_web_config(webapp_path)
    prefix = Tomcat.get_namespace_prefix(web_config)
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
      Tomcat.save_web_config(web_config, webapp_path)
    else
      raise "Scala / Lift application staging failed: no LiftFilter class found in web.xml"
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
