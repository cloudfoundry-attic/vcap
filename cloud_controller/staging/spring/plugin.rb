require File.join(File.expand_path('../../java_web', __FILE__), 'plugin.rb')

class SpringPlugin < JavaWebPlugin
  def framework
    'spring'
  end

  def autostaging_template
    File.join(File.dirname(__FILE__), '../java_web/resources', 'autostaging_template_spring.xml')
  end

  def skip_staging webapp_root
    false
  end

end
