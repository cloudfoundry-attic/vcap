require 'nokogiri'
require 'fileutils'

class Tomcat
  DEFAULT_APP_CONTEXT = "/WEB-INF/applicationContext.xml"
  DEFAULT_SERVLET_CONTEXT_SUFFIX = "-servlet.xml"
  ANNOTATION_CONTEXT_CLASS = "org.springframework.web.context.support.AnnotationConfigWebApplicationContext"

  def self.resource_dir
    File.join(File.dirname(__FILE__), 'resources')
  end

  def self.prepare(dir)
    FileUtils.cp_r(resource_dir, dir)
    output = %x[cd #{dir}; unzip -q resources/tomcat.zip]
    raise "Could not unpack Tomcat: #{output}" unless $? == 0
    webapp_path = File.join(dir, "tomcat", "webapps", "ROOT")
    server_xml = File.join(dir, "tomcat", "conf", "server.xml")
    FileUtils.rm_f(server_xml)
    FileUtils.rm(File.join(dir, "resources", "tomcat.zip"))
    FileUtils.mv(File.join(dir, "resources", "droplet.yaml"), dir)
    FileUtils.mkdir_p(webapp_path)
    webapp_path
  end

  def self.get_namespace_prefix(webapp_config)
    name_space = webapp_config.root.namespace
    if name_space
      if name_space.prefix
        prefix = name_space.prefix
      else
        prefix = "xmlns:"
      end
    else
      prefix = ''
    end
  end

  # The staging modifications that are common to one or more framework plugins e.g. ['spring' & 'grails'
  # requiring autostaging context_param & autostaging servlet updates and 'spring', 'grails' & 'lift'
  # requiring the copying of the autostaging jar etc] are handled below to avoid duplication.
  # Modifications that are specific to a framework are handled in the associated plugin (for e.g. configuring
  # the springenv context_param that is specific to 'spring' and configuring a servlet_context_listener
  # that is specific to 'lift'). The driver from which all of the staging modifications for each framework is
  # made is the "configure_webapp" method of each framework plugin.

  # Look for the presence of the "context-param" element in the top level (global context) of WEB-INF/web.xml
  # and for a "contextConfigLocation" node within that.
  # If present, update it if necessary (i.e. it does have a valid location) to include the context reference
  # (provided by autostaging_context) that will handle autostaging.
  # If not present, check for the presence of a default app context at WEB-INF/applicationContext.xml. If a
  # default app context is present, introduce a "contextConfigLocation" element and set its value to include
  # both the default app context as well as the context reference for autostaging.
  def self.configure_autostaging_context_param(autostaging_context, webapp_config, webapp_path)
    autostaging_context_param_node = autostaging_context.xpath("//context-param[param-name='contextConfigLocation']").first
    autostaging_context_param_name_node = autostaging_context_param_node.xpath("param-name").first
    autostaging_context_param_name = autostaging_context_param_name_node.content.strip
    autostaging_context_param_value_xml_node = autostaging_context.xpath("//context-param/param-value").first
    prefix = get_namespace_prefix(webapp_config)
    autostaging_context_param_anno_node = autostaging_context.xpath("//context-param[param-name='contextConfigLocationAnnotationConfig']").first
    if autostaging_context_param_anno_node
      autostaging_context_param_value_anno_node = autostaging_context_param_anno_node.xpath("param-value").first
    else
      autostaging_context_param_value_anno_node = nil
    end
    cc = webapp_config.xpath("//#{prefix}context-param[contains(normalize-space(#{prefix}param-name), normalize-space('contextClass'))]")
    if autostaging_context_param_value_anno_node && cc.xpath("#{prefix}param-value").text == ANNOTATION_CONTEXT_CLASS
      autostaging_context_param_value_node = autostaging_context_param_value_anno_node
    else
      autostaging_context_param_value_node = autostaging_context_param_value_xml_node
    end
    autostaging_context_param_value = autostaging_context_param_value_node.content

    context_param_nodes =  webapp_config.xpath("//#{prefix}context-param")
    if (context_param_nodes != nil && context_param_nodes.length > 0)
      context_param_node = webapp_config.xpath("//#{prefix}context-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{autostaging_context_param_name}'))]").first
      if (context_param_node != nil)
        webapp_config = update_context_value context_param_node.parent, prefix, "context-param", webapp_config, autostaging_context_param_name, autostaging_context_param_value
      else
        default_application_context_file = get_default_application_context_file(webapp_path)
        unless default_application_context_file == nil
          context_param_node = context_param_nodes.first
          webapp_config = configure_default_context webapp_path, webapp_config, autostaging_context_param_name_node, autostaging_context_param_value, context_param_node, DEFAULT_APP_CONTEXT
        end
      end
    else
      default_application_context_file = get_default_application_context_file(webapp_path)
      unless default_application_context_file == nil
        context_param_node = Nokogiri::XML::Node.new 'context-param', webapp_config
        webapp_config.root.add_child context_param_node
        webapp_config = configure_default_context webapp_path, webapp_config, autostaging_context_param_name_node, autostaging_context_param_value, context_param_node, DEFAULT_APP_CONTEXT
      end
    end
    webapp_config
  end

  # Look for the presence of the "init-param" element in the DispatcherServlet element of WEB-INF/web.xml
  # and for a "contextConfigLocation" node within that.
  # If present, update it to include the context reference (provided by the autostaging_context) that
  # will handle autostaging.
  # If not present, check for the presence of a default servlet context at
  # WEB-INF/<servlet-name>-applicationContext.xml. If a default app context is present,
  # introduce a "contextConfigLocation" element and set its value to include
  # both the default servlet context as well as the context reference for autostaging.
  def self.configure_autostaging_servlet (autostaging_context, webapp_config, webapp_path)
    autostaging_servlet_class = autostaging_context.xpath("//servlet-class").first.content.strip
    autostaging_init_param_name_node = autostaging_context.xpath("//servlet/init-param/param-name").first
    autostaging_init_param_name = autostaging_init_param_name_node.content.strip
    autostaging_init_param_value_xml_node = autostaging_context.xpath("//servlet/init-param/param-value").first
    autostaging_init_param_anno_node = autostaging_context.xpath("//servlet/init-param[param-name='contextConfigLocationAnnotationConfig']").first
    if autostaging_init_param_anno_node
      autostaging_init_param_value_anno_node = autostaging_init_param_anno_node.xpath("param-value").first
    else
      autostaging_init_param_value_anno_node = nil
    end
    prefix = get_namespace_prefix(webapp_config)
    cc = webapp_config.xpath("//#{prefix}servlet/#{prefix}init-param[contains(normalize-space(#{prefix}param-name), normalize-space('contextClass'))]")
    if autostaging_init_param_value_anno_node && cc.xpath("#{prefix}param-value").text == ANNOTATION_CONTEXT_CLASS
      autostaging_init_param_value_node = autostaging_init_param_value_anno_node
    else
      autostaging_init_param_value_node = autostaging_init_param_value_xml_node
    end
    autostaging_init_param_value = autostaging_init_param_value_node.content

    dispatcher_servlet_nodes = webapp_config.xpath("//#{prefix}servlet[contains(normalize-space(#{prefix}servlet-class), normalize-space('#{autostaging_servlet_class}'))]")
    if (dispatcher_servlet_nodes != nil && !dispatcher_servlet_nodes.empty?)
      dispatcher_servlet_nodes.each do |dispatcher_servlet_node|
        dispatcher_servlet_name = dispatcher_servlet_node.xpath("#{prefix}servlet-name").first.content.strip
        default_servlet_context = "/WEB-INF/#{dispatcher_servlet_name}#{DEFAULT_SERVLET_CONTEXT_SUFFIX}"
        init_param_node = dispatcher_servlet_node.xpath("#{prefix}init-param").first
        if init_param_node != nil
          init_param_name_node = dispatcher_servlet_node.xpath("#{prefix}init-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{autostaging_init_param_name}'))]").first
          if init_param_name_node != nil
            webapp_config = update_context_value dispatcher_servlet_node, prefix, "init-param", webapp_config, autostaging_init_param_name, autostaging_init_param_value
          else
            webapp_config = configure_init_param_node(autostaging_init_param_name_node, autostaging_init_param_value, autostaging_init_param_value_node, default_servlet_context, dispatcher_servlet_name, dispatcher_servlet_node, init_param_node, webapp_config, webapp_path)
          end
        else
          init_param_node = Nokogiri::XML::Node.new 'init-param', webapp_config
          webapp_config = configure_init_param_node(autostaging_init_param_name_node, autostaging_init_param_value, autostaging_init_param_value_node, default_servlet_context, dispatcher_servlet_name, dispatcher_servlet_node, init_param_node, webapp_config, webapp_path)
        end
      end
    end
    webapp_config
  end

  def self.configure_default_context webapp_path, webapp_config, autostaging_context_param_name_node, autostaging_context_param_value, parent, default_context
    context_param_value = "#{default_context} #{autostaging_context_param_value}"
    context_param_value_node = Nokogiri::XML::Node.new 'param-value', webapp_config
    context_param_value_node.content = context_param_value

    parent.add_child autostaging_context_param_name_node.dup
    parent.add_child context_param_value_node

    webapp_config

  end

  def self.update_context_value parent, prefix, selector, webapp_config, autostaging_context_param_name, autostaging_context_param_value
    node = parent.xpath("#{prefix}#{selector}[contains(normalize-space(#{prefix}param-name), normalize-space('#{autostaging_context_param_name}'))]").first
    context_param_value_node = node.xpath("#{prefix}param-value")
    context_param_value = context_param_value_node.first.content

    unless context_param_value.split.include?(autostaging_context_param_value) || context_param_value == ''
      node.xpath("#{prefix}param-value").first.unlink
      context_param_value << " #{autostaging_context_param_value}"

      context_param_value_node = Nokogiri::XML::Node.new 'param-value', webapp_config
      context_param_value_node.content = context_param_value
      node.add_child context_param_value_node
    end
    webapp_config

  end

  def self.get_default_application_context_file(webapp_path)
    default_application_context = File.join(webapp_path, 'WEB-INF/applicationContext.xml')
    if File.exist? default_application_context
      return default_application_context
    end
    nil
  end

  def self.get_default_servlet_context_file(webapp_path, servlet_name)
    default_servlet_context = File.join(webapp_path, "WEB-INF/#{servlet_name}#{DEFAULT_SERVLET_CONTEXT_SUFFIX}")
    if File.exist? default_servlet_context
      return default_servlet_context
    end
    nil
  end

  def self.configure_init_param_node(autostaging_init_param_name_node, autostaging_init_param_value, autostaging_init_param_value_node, default_servlet_context, dispatcher_servlet_name, dispatcher_servlet_node, init_param_node, webapp_config, webapp_path)
    default_servlet_context_file = get_default_servlet_context_file(webapp_path, dispatcher_servlet_name)
    dispatcher_servlet_node.add_child init_param_node
    unless default_servlet_context_file == nil
      webapp_config = configure_default_context webapp_path, webapp_config, autostaging_init_param_name_node, autostaging_init_param_value, init_param_node, default_servlet_context
    else
      init_param_node.add_child autostaging_init_param_name_node.dup
      init_param_node.add_child autostaging_init_param_value_node.dup
    end
    webapp_config
  end

  def self.get_autostaging_context autostaging_template
    Nokogiri::XML(open(autostaging_template))
  end

  def self.get_web_config (webapp_path)
    web_config_file = File.join(webapp_path, 'WEB-INF/web.xml')
    Nokogiri::XML(open(web_config_file))
  end

  def self.save_web_config (web_config, webapp_path)
    web_config_file = File.join(webapp_path, 'WEB-INF/web.xml')
    File.open(web_config_file, 'w') {|f| f.write(web_config.to_xml) }
  end

  def self.insight_bound? services
    services.any? { |service| service if service[:name] =~ /^Insight-.*/ and service[:label] =~ /^rabbitmq-*/ } if services #
  end

  def self.prepare_insight dir, environment, agent=nil

    unless is_dashboard?(dir) or agent == nil or File.exists?(agent) == false
      output = `unzip -q "#{agent}" -d "#{Dir.pwd}"`
      raise "Could not unpack agent #{agent}: #{output}" unless $? == 0

      tomcat_dir = File.join(dir, "tomcat")
      output = %x[cd cf-tomcat-agent-javaagent-* ; bash install.sh #{tomcat_dir}]
      raise "Could not install agent: #{output}" unless $? == 0

      appname = environment[:name] || 'ROOT'
      insight_props = File.join(dir, "tomcat", "insight", "insight.properties")
      text = File.read(insight_props)
      File.open(insight_props, "w") {|file| file.puts text.gsub(/appname/, "#{appname}")}

    end
  end

  def self.is_dashboard?(dir)
    insight_props = File.join(dir, "tomcat", "webapps", "ROOT", "insight", "insight.properties")
    File.exists?(insight_props)
  end

end
