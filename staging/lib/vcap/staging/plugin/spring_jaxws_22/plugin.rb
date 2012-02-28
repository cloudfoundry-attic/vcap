require 'fileutils'
require File.join(File.expand_path('../../spring', __FILE__), 'plugin.rb')

# This plugin adds Metro JAX-WS 2.2.3 API jars to the Tomcat endorsed dir.
class SpringJaxws22Plugin < SpringPlugin
  def framework
    'spring_jaxws22'
  end

  def autostaging_template
    nil
  end

  def skip_staging webapp_root
    false
  end

  def configure_webapp webapp_path, autostaging_template, environment
    copy_jaxws_jars(webapp_path)
  end

  def copy_jaxws_jars webapp_path
    endorsed_dir = File.join(webapp_path, '../../endorsed')
    FileUtils.mkdir_p(endorsed_dir)

    jar_path = File.join(File.dirname(__FILE__), 'resources/.')
    FileUtils.cp_r(jar_path, endorsed_dir)
  end

end
