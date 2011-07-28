require 'nokogiri'
require 'fileutils'

class Tomcat
  AUTOSTAGING_JAR = 'auto-reconfiguration-0.6.0-BUILD-SNAPSHOT.jar'
  DEFAULT_APP_CONTEXT = "/WEB-INF/applicationContext.xml"
  DEFAULT_SERVLET_CONTEXT_SUFFIX = "-servlet.xml"

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

  def self.configure_tomcat_application(staging_dir, webapp_root, autostaging_template, environment)
    configure_autostaging(webapp_root, autostaging_template)
  end

  def self.configure_autostaging(webapp_path, autostaging_template)
    web_config_file = File.join(webapp_path, 'WEB-INF/web.xml')
    autostaging_context = get_autostaging_context autostaging_template
    if File.exist? web_config_file
      modify_autostaging_context(autostaging_context, web_config_file, webapp_path)
    else
      raise "Spring / J2EE application staging failed: web.xml not found"
    end
    jar_dest = File.join(webapp_path, 'WEB-INF/lib')
    copy_jar AUTOSTAGING_JAR, jar_dest
  end

  def self.modify_autostaging_context(autostaging_context, web_config_file, webapp_path)
    web_config = Nokogiri::XML(open(web_config_file))
    web_config = configure_autostaging_context_param autostaging_context, web_config, webapp_path
    web_config = configure_autostaging_servlet autostaging_context, web_config, webapp_path
    File.open(web_config_file, 'w') {|f| f.write(web_config.to_xml) }
  end

  # Look for the presence of the "context-param" element in the top level (global context) of WEB-INF/web.xml
  # and for a "contextConfigLocation" node within that.
  # If present, update it if necessary (i.e. it does have a valid location) to include the context reference
  # (provided by autostaging_context) that will handle autostaging.
  # If not present, check for the presence of a default app context at WEB-INF/applicationContext.xml. If a
  # default app context is present, introduce a "contextConfigLocation" element and set its value to include
  # both the default app context as well as the context reference for autostaging.
  def self.configure_autostaging_context_param(autostaging_context, webapp_config, webapp_path)
    autostaging_context_param_name_node = autostaging_context.xpath("//context-param/param-name").first
    autostaging_context_param_name = autostaging_context_param_name_node.content.strip
    autostaging_context_param_value_node = autostaging_context.xpath("//context-param/param-value").first
    autostaging_context_param_value = autostaging_context_param_value_node.content

    prefix = webapp_config.root.namespace ? "xmlns:" : ''
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
    autostaging_init_param_value_node = autostaging_context.xpath("//servlet/init-param/param-value").first
    autostaging_init_param_value = autostaging_init_param_value_node.content

    prefix = webapp_config.root.namespace ? "xmlns:" : ''
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

    parent.add_child autostaging_context_param_name_node
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
      init_param_node.add_child autostaging_init_param_name_node
      init_param_node.add_child autostaging_init_param_value_node
    end
    webapp_config
  end

  def self.copy_jar jar, dest
    jar_path = File.join(File.dirname(__FILE__), 'resources', jar)
    FileUtils.mkdir_p dest
    FileUtils.cp(jar_path, dest)
  end

  def self.get_autostaging_context autostaging_template
    Nokogiri::XML(open(autostaging_template))
  end

end
