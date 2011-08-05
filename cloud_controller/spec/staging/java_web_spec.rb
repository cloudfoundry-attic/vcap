require 'spec_helper'

describe "A Java web application being staged without a web config" do
  before do
    app_fixture :java_web_no_web_config
  end

  it "should fail" do
    lambda { stage :java_web }.should raise_error
  end
end

describe "A Java web being staged " do
  before(:all) do
    app_fixture :java_web
  end

  it "should not be modified during staging" do
    stage :java_web do |staged_dir|
      web_config_file = File.join(staged_dir, 'tomcat/webapps/ROOT/WEB-INF/web.xml')
      File.exist?(web_config_file).should == true

      web_config = Nokogiri::XML(open(web_config_file))
      context_param_node =  web_config.xpath("//context-param")
      context_param_node.length.should == 0
    end
  end

  it "should not have the auto reconfiguration jar in the webapp lib path" do
    stage :java_web do |staged_dir|
      auto_reconfig_jar_relative_path = "tomcat/webapps/ROOT/WEB-INF/lib/#{AUTOSTAGING_JAR}"
      auto_reconfiguration_jar_path = File.join(staged_dir, auto_reconfig_jar_relative_path)
      File.exist?(auto_reconfiguration_jar_path).should == false
    end
  end

end
