require 'spec_helper'

AUTOSTAGING_JAR = 'auto-reconfiguration-0.6.0-BUILD-SNAPSHOT.jar'

describe "A Grails application being staged without a context-param in its web config and with a default application context config" do
  before(:all) do
    app_fixture :grails_default_appcontext_no_context_config
  end

  it "should have a context-param in its web config after staging" do
    stage :grails do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      context_param_node =  web_config.xpath("//context-param")
      context_param_node.length.should_not == 0
    end
  end

  it "should have a 'contextConfigLocation' where the default application context precedes the auto-reconfiguration context" do
    stage :grails do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      web_config = Nokogiri::XML(open(web_config_file))
      context_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
      context_param_name_node.length.should_not == 0

      context_param_value_node = context_param_name_node.first.xpath("param-value")
      context_param_value_node.length.should_not == 0

      context_param_value = context_param_value_node.first.content
      default_context_index = context_param_value.index('/WEB-INF/applicationContext.xml')
      default_context_index.should_not == nil

      auto_reconfiguration_context_index = context_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
      auto_reconfiguration_context_index.should_not == nil

      auto_reconfiguration_context_index.should > default_context_index + "/WEB-INF/applicationContext.xml".length
    end
  end

  it "should have the auto reconfiguration jar in the webapp lib path" do
    stage :grails do |staged_dir|
      auto_reconfig_jar_relative_path = "tomcat/webapps/ROOT/WEB-INF/lib/#{AUTOSTAGING_JAR}"
      auto_reconfiguration_jar_path = File.join(staged_dir, auto_reconfig_jar_relative_path)
      File.exist?(auto_reconfiguration_jar_path).should == true
    end
  end

end

# This application is the exact same one as the one above but with a Grails configuration indicating the presence
# of a CloudFoundryGrailsPlugin which indicates that staging should not make any modifications.
describe "A Grails application being staged without a context-param in its web config and with a default application context config and a Grails plugin file" do
  before(:all) do
    app_fixture :grails_skip_autoconfig
  end

  it "should not be modified during staging" do
    stage :grails do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      context_param_node =  web_config.xpath("//context-param")
      context_param_node.length.should == 0
    end
  end

  it "should not have the auto reconfiguration jar in the webapp lib path" do
    stage :grails do |staged_dir|
      auto_reconfig_jar_relative_path = "tomcat/webapps/ROOT/WEB-INF/lib/#{AUTOSTAGING_JAR}"
      auto_reconfiguration_jar_path = File.join(staged_dir, auto_reconfig_jar_relative_path)
      File.exist?(auto_reconfiguration_jar_path).should == false
    end
  end

end
