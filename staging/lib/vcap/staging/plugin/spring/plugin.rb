require File.join(File.expand_path('../../java_web', __FILE__), 'plugin.rb')

class SpringPlugin < JavaWebPlugin
  def framework
    'spring'
  end

  def autostaging_template
    File.join(File.dirname(__FILE__), 'autostaging_template_spring.xml')
  end

  def skip_staging webapp_root
    false
  end

  def configure_webapp webapp_path, autostaging_template, environment
    autostaging_context = Tomcat.get_autostaging_context autostaging_template
    web_config = Tomcat.get_web_config(webapp_path)
    web_config = Tomcat.configure_autostaging_context_param autostaging_context, web_config, webapp_path
    web_config = configure_springenv_context_param autostaging_context, web_config, webapp_path
    web_config = Tomcat.configure_autostaging_servlet autostaging_context, web_config, webapp_path
    Tomcat.save_web_config(web_config, webapp_path)
    copy_autostaging_jar File.join(webapp_path, 'WEB-INF/lib')
  end

  def configure_springenv_context_param(autostaging_context, webapp_config, webapp_path)
    autostaging_context_param_node = autostaging_context.xpath("//context-param[param-name='contextInitializerClasses']").first
    autostaging_context_param_name_node = autostaging_context_param_node.xpath("param-name").first
    autostaging_context_param_value_node = autostaging_context_param_node.xpath("param-value").first
    autostaging_context_param_value = autostaging_context_param_value_node.content

    prefix = Tomcat.get_namespace_prefix(webapp_config)
    context_param_node =  webapp_config.xpath("//#{prefix}context-param[#{prefix}param-name='contextInitializerClasses']").first
    if (context_param_node == nil)
      context_param_node = Nokogiri::XML::Node.new 'context-param', webapp_config
      context_param_node.add_child autostaging_context_param_name_node.dup
      context_param_node.add_child autostaging_context_param_value_node.dup
      webapp_config.root.add_child context_param_node
    else
      context_param_value_node = context_param_node.xpath("#{prefix}param-value").first
      context_param_value = "#{context_param_value_node.content.strip}, #{autostaging_context_param_value}"
      context_param_value_node.content = context_param_value
    end
    webapp_config
  end

end
