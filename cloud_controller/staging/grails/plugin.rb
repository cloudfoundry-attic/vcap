require File.join(File.expand_path('../../java_web', __FILE__), 'plugin.rb')
require 'nokogiri'


class GrailsPlugin < JavaWebPlugin
  VMC_GRAILS_PLUGIN = "CloudFoundryGrailsPlugin"
  def framework
    'grails'
  end

  def autostaging_template
    File.join(File.dirname(__FILE__), 'autostaging_template_grails.xml')
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

end
