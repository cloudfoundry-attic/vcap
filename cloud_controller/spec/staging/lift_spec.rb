# Copyright (c) 2009-2011 VMware, Inc.
# Author: A.B.Srinivasan - asrinivasan@vmware.com

require 'spec_helper'

AUTOSTAGING_JAR = 'auto-reconfiguration-0.6.0-BUILD-SNAPSHOT.jar'
LIFT_FILTER_CLASS = 'net.liftweb.http.LiftFilter'
CF_LIFT_PROPERTIES_GENERATOR_FILTER =
  'CloudLiftServicesPropertiesGeneratorFilter'
CF_LIFT_PROPERTIES_GENERATOR_FILTER_CLASS =
  'org.cloudfoundry.reconfiguration.CloudLiftServicesPropertiesGeneratorFilter';

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

describe "A Lift application being staged will contain a CloudLiftServicesPropertiesGeneratorFilter in its web config after staging" do
  before(:all) do
    app_fixture :lift_simple
  end

  it "should contain a CloudLiftServicesPropertiesGeneratorFilter filter in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_filter = web_config.xpath("//web-app/filter[contains(
                                          normalize-space(#{prefix}filter-class),
                                          '#{CF_LIFT_PROPERTIES_GENERATOR_FILTER_CLASS}')]")
      lift_filter.length.should_not == 0
    end
  end

  it "should contain a CloudLiftServicesPropertiesGeneratorFilter filter-map in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      cf_lift_filter_map = web_config.xpath("//web-app/filter-mapping[contains(
                                         normalize-space(#{prefix}filter-name),
                                         '#{CF_LIFT_PROPERTIES_GENERATOR_FILTER}')]")
      cf_lift_filter_map.length.should_not == 0
    end
  end

  it "should contain a CloudLiftServicesPropertiesGeneratorFilter filter before the LiftFilter filter in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_filter = web_config.xpath("//web-app/filter[contains(
                                          normalize-space(#{prefix}filter-class),
                                          '#{LIFT_FILTER_CLASS}')]")
      lift_filter.length.should_not == 0

      cf_lift_filter = lift_filter.first.previous_sibling
      cf_lift_filter.should_not == nil

      cf_lift_filter_class = cf_lift_filter.xpath("filter-class")
      cf_lift_filter_class.length.should_not == 0

      cf_lift_filter_class.first.content.should == "#{CF_LIFT_PROPERTIES_GENERATOR_FILTER_CLASS}"
    end
  end

  it "should contain a CloudLiftServicesPropertiesGeneratorFilter filter-map before the LiftFilter filter-map in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_filter = web_config.xpath("//web-app/filter[contains(
                                          normalize-space(#{prefix}filter-class),
                                          '#{LIFT_FILTER_CLASS}')]")
      lift_filter.length.should_not == 0

      lift_filter_name = lift_filter.first.xpath("#{prefix}filter-name").first.content
      lift_filter_map = web_config.xpath("//web-app/filter-mapping[contains(
                                          normalize-space(#{prefix}filter-name),
                                          '#{lift_filter_name}')]")
      lift_filter_map.length.should_not == 0

      cf_lift_filter_map = lift_filter_map.first.previous_sibling
      cf_lift_filter_map.should_not == nil

      cf_lift_filter_map_name = cf_lift_filter_map.xpath("filter-name")
      cf_lift_filter_map_name.length.should_not == 0

      cf_lift_filter_map_name.first.content.should == "#{CF_LIFT_PROPERTIES_GENERATOR_FILTER}"
    end
  end

  it "the CloudLiftServicesPropertiesGeneratorFilter filter-map's url-pattern should match that of the LiftFilter filter-map in its web config" do
    stage :lift do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      prefix = web_config.root.namespace ? "xmlns:" : ''
      lift_filter = web_config.xpath("//web-app/filter[contains(
                                          normalize-space(#{prefix}filter-class),
                                          '#{LIFT_FILTER_CLASS}')]")
      lift_filter.length.should_not == 0
      lift_filter_name = lift_filter.first.xpath("#{prefix}filter-name").first.content

      lift_filter_map = web_config.xpath("//web-app/filter-mapping[contains(
                                          normalize-space(#{prefix}filter-name),
                                          '#{lift_filter_name}')]")
      lift_filter_map.length.should_not == 0

      lift_filter_map_url_pattern = lift_filter_map.first.xpath("url-pattern")
      lift_filter_map_url_pattern.length.should_not == 0

      cf_lift_filter_map = lift_filter_map.first.previous_sibling
      cf_lift_filter_map.should_not == nil

      cf_lift_filter_map_url_pattern = cf_lift_filter_map.xpath("url-pattern")
      cf_lift_filter_map_url_pattern.length.should_not == 0

      cf_lift_filter_map_url_pattern.first.content.should == lift_filter_map_url_pattern.first.content
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
