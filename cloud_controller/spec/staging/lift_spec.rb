# Copyright (c) 2009-2011 VMware, Inc.
# Author: A.B.Srinivasan - asrinivasan@vmware.com

require 'spec_helper'

AUTOSTAGING_JAR = 'auto-reconfiguration-0.6.0-BUILD-SNAPSHOT.jar'
LIFT_FILTER_CLASS = 'net.liftweb.http.LiftFilter'
CF_LIFT_PROPERTIES_GENERATOR_CLASS =
  'org.cloudfoundry.reconfiguration.CloudLiftServicesPropertiesGenerator';

describe "A Lift application being staged without a web.xml in its web config will be rejected" do
  before(:all) do
    app_fixture :lift_no_web_config
  end

  it "should be fail the staging" do
    lambda { stage :lift }.should raise_error("Scala / Lift application staging failed: web.xml not found")
  end
end

describe "A Lift application being staged without a LiftFilter in its web config will be rejected" do
  before(:all) do
    app_fixture :lift_no_lift_filter
  end

  it "should fail the staging" do
    lambda { stage :lift }.should raise_error("Scala / Lift application staging failed: no LiftFilter class found in web.xml")
  end
end

describe "A Lift application with only a LiftFilter being staged will contain a CloudLiftServicesPropertiesGenerator in its web config after staging" do
  before(:all) do
    app_fixture :lift_simple
  end

  it "should contain a CloudLiftServicesPropertiesGenerator ServletContextListener in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_context_listener = web_config.xpath("//web-app/listener[contains(
                                          normalize-space(#{prefix}listener-class),
                                          '#{CF_LIFT_PROPERTIES_GENERATOR_CLASS}')]")
      lift_context_listener.length.should_not == 0
    end
  end

  it "should contain the CloudLiftServicesPropertiesGenerator ServletContextListener before the LiftFilter in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_filter = web_config.xpath("//web-app/filter[contains(
                                          normalize-space(#{prefix}filter-class),
                                          '#{LIFT_FILTER_CLASS}')]")
      lift_filter.length.should_not == 0

      lift_context_listener = lift_filter.first.previous_sibling
      lift_context_listener.should_not == nil

      lift_context_listener_class = lift_context_listener.xpath("listener-class")
      lift_context_listener_class.length.should_not == 0
      lift_context_listener_class.first.content.should == "#{CF_LIFT_PROPERTIES_GENERATOR_CLASS}"

    end
  end

  it "should have the auto reconfiguration jar in the webapp lib path" do
    stage :lift do |staged_dir|
      auto_reconfig_jar_relative_path = "tomcat/webapps/ROOT/WEB-INF/lib/#{AUTOSTAGING_JAR}"
      auto_reconfiguration_jar_path = File.join(staged_dir, auto_reconfig_jar_relative_path)
      File.exist?(auto_reconfiguration_jar_path).should == true
    end
  end

end

describe "A Lift application with a servlet and a LiftFilter being staged will contain a CloudLiftServicesPropertiesGenerator in its web config after staging" do
  before(:all) do
    app_fixture :lift_simple_servlet
  end

  it "should contain a CloudLiftServicesPropertiesGenerator ServletContextListener in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_context_listener = web_config.xpath("//web-app/listener[contains(
                                          normalize-space(#{prefix}listener-class),
                                          '#{CF_LIFT_PROPERTIES_GENERATOR_CLASS}')]")
      lift_context_listener.length.should_not == 0
    end
  end

  it "should contain the CloudLiftServicesPropertiesGenerator ServletContextListener before the servlet in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      lift_servlet = web_config.xpath("//web-app/servlet")
      lift_servlet.length.should_not == 0

      lift_context_listener = lift_servlet.first.previous_sibling
      lift_context_listener.should_not == nil

      lift_context_listener_class = lift_context_listener.xpath("listener-class")
      lift_context_listener_class.length.should_not == 0
      lift_context_listener_class.first.content.should == "#{CF_LIFT_PROPERTIES_GENERATOR_CLASS}"

    end
  end

  it "should have the auto reconfiguration jar in the webapp lib path" do
    stage :lift do |staged_dir|
      auto_reconfig_jar_relative_path = "tomcat/webapps/ROOT/WEB-INF/lib/#{AUTOSTAGING_JAR}"
      auto_reconfiguration_jar_path = File.join(staged_dir, auto_reconfig_jar_relative_path)
      File.exist?(auto_reconfiguration_jar_path).should == true
    end
  end

end