require 'spec_helper'
require 'fileutils'

describe "A Java web application being staged without a web config" do
  before do
    app_fixture :java_web_no_web_config
  end

  it "should fail" do
    lambda { stage(:java_web){} }.should raise_error
  end
end

describe "A Java web application being staged " do
  before(:all) do
    app_fixture :java_web
  end

  it "should not be modified during staging" do
    stage :java_web do |staged_dir, source_dir|
      source_app_files = Dir.glob("#{source_dir}/**/*", File::FNM_DOTMATCH)
      staged_app_root = File.join(staged_dir, 'tomcat/webapps/ROOT')
      staged_app_files = Dir.glob("#{staged_app_root}/**/*", File::FNM_DOTMATCH)
      source_app_files.should_not == nil
      staged_app_files.should_not == nil
      source_app_files.length.should == staged_app_files.length
      source_app_files.each do |filename|
        next if File.directory?(filename)
        staged_app_file = filename.sub(/#{source_dir}/, "#{staged_app_root}")
        File.exists?(staged_app_file).should == true
        FileUtils.compare_file(filename, staged_app_file).should == true
      end
    end
  end

end

describe "A Java web application being staged with a MySql service bound to it" do
  before(:all) do
    app_fixture :java_web
    @environment = {
      :services => [
                    {:label=>"mysql-5.1", :tags=>["mysql", "mysql-5.1", "relational"], :name=>"mysql-9db41", :credentials=>{:name=>"d1b5ec5b179dc439d9c657dcc0ab9131c", :hostname=>"127.0.0.1", :host=>"127.0.0.1", :port=>3306, :user=>"upRQ0PsA7oEJD", :username=>"upRQ0PsA7oEJD", :password=>"pibhMxdwYZqy5"}, :options=>{}, :plan=>"free", :plan_option=>nil}
                   ]
    }
  end

  it "should have the MySql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{MYSQL_DRIVER_JAR}").should == true
    end
  end

  it "should not have the PostgreSql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{POSTGRESQL_DRIVER_JAR}").should_not == true
    end
  end

end

describe "A Java web application being staged with a PostgreSql service bound to it" do
  before(:all) do
    app_fixture :java_web
    @environment = {
      :services => [
                    {:label=>"postgresql-9.0", :tags=>["postgresql", "postgresql-9.0", "relational"], :name=>"postgresql-9db41", :credentials=>{:name=>"d5cb067dbd29a4f37b4a17d8e9890b3db", :hostname=>"172.30.48.125", :host=>"172.30.48.125", :port=>5432, :user=>"upRQ0PsA7oEJD", :username=>"upRQ0PsA7oEJD", :password=>"pibhMxdwYZqy5"}, :options=>{}, :plan=>"free", :plan_option=>nil}
                   ]
    }
  end

  it "should have the PostgreSql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{POSTGRESQL_DRIVER_JAR}").should == true
    end
  end

  it "should not have the MySql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{MYSQL_DRIVER_JAR}").should_not == true
    end
  end

end

describe "A Java web application being staged with a MySql and a PostgreSql service bound to it" do
  before(:all) do
    app_fixture :java_web
    @environment = {
      :services => [
                    {:label=>"mysql-5.1", :tags=>["mysql", "mysql-5.1", "relational"], :name=>"mysql-9db41", :credentials=>{:name=>"d1b5ec5b179dc439d9c657dcc0ab9131c", :hostname=>"127.0.0.1", :host=>"127.0.0.1", :port=>3306, :user=>"upRQ0PsA7oEJD", :username=>"upRQ0PsA7oEJD", :password=>"pibhMxdwYZqy5"}, :options=>{}, :plan=>"free", :plan_option=>nil},
                    {:label=>"postgresql-9.0", :tags=>["postgresql", "postgresql-9.0", "relational"], :name=>"postgresql-9db41", :credentials=>{:name=>"d5cb067dbd29a4f37b4a17d8e9890b3db", :hostname=>"172.30.48.125", :host=>"172.30.48.125", :port=>5432, :user=>"upRQ0PsA7oEJD", :username=>"upRQ0PsA7oEJD", :password=>"pibhMxdwYZqy5"}, :options=>{}, :plan=>"free", :plan_option=>nil}
                   ]
    }
  end

  it "should have the MySql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{MYSQL_DRIVER_JAR}").should == true
    end
  end

  it "should have the PostgreSql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{POSTGRESQL_DRIVER_JAR}").should == true
    end
  end

end

describe "A Java web application being staged without a MySql or a PostgreSql service bound to it" do
  before(:all) do
    app_fixture :java_web
    @environment = {}
  end

  it "should not have the MySql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{MYSQL_DRIVER_JAR}").should_not == true
    end
  end

  it "should not have the PostgreSql driver in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "tomcat/lib/#{POSTGRESQL_DRIVER_JAR}").should_not == true
    end
  end

end

describe "A Java web application being staged with Insight bound to it" do
  before(:all) do
    app_fixture :java_web
    @environment = {
      :services => [
                    {:label=>"rabbitmq-2.4", :tags=>["rabbitmq"], :name=>"Insight-9db41", :options=>{:url => "amqp://ehpbqzli:78Qts7GBH1AYH349@172.31.248.71:29522/gfzqolvo"}, :plan=>"free", :plan_option=>nil}
                   ]
    }
  end

  it "should have the Insight agent in the Tomcat library" do
    pending "Availability of Insight"
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "#{INSIGHT_AGENT}").should == true
    end
  end

end

describe "A Java web application being staged without Insight bound to it" do
  before(:all) do
    app_fixture :java_web
    @environment = {}
  end

  it "should not have the Insight agent in the Tomcat library" do
    stage(:java_web, @environment) do |staged_dir, source_dir|
      jar_present?(staged_dir, "#{INSIGHT_AGENT}").should_not == true
    end
  end

end

def jar_present? staged_dir, path
  File.exist?(File.join(staged_dir, path))
end
