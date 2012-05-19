require 'spec_helper'

describe "A Play app being staged" do
  before do
    app_fixture :play_app
  end

  it "is packaged with a startup script" do
    stage :play, {:resources=>{:memory=>256}} do |staged_dir|
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
cd app
./start -Xms256m -Xmx256m -Dhttp.port=$VCAP_APP_PORT $JAVA_OPTS > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
    end
  end

  it "has an executable app start script with replaced main class" do
    stage :play, {:services=>[]} do |staged_dir|
      start_script = File.join(staged_dir, 'app','start')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/usr/bin/env sh

exec java $* -cp "`dirname $0`/lib/*" org.cloudfoundry.reconfiguration.play.Bootstrap `dirname $0`
      EXPECTED
    end
  end

  it "is packaged with a postgres driver if not present" do
    stage :play, {:services=>[{:label=>"postgresql-9.0"}]} do |staged_dir|
      jar_present?(staged_dir, "app/lib/#{POSTGRESQL_DRIVER_JAR}").should == true
      jar_present?(staged_dir, "app/lib/#{MYSQL_DRIVER_JAR}").should == false
    end
  end

  it "is packaged with a mysql driver if not present" do
    stage :play, {:services=>[{:label=>"mysql-5.1"}]} do |staged_dir|
     jar_present?(staged_dir, "app/lib/#{POSTGRESQL_DRIVER_JAR}").should == false
     jar_present?(staged_dir, "app/lib/#{MYSQL_DRIVER_JAR}").should == true
    end
  end

  it "is not packaged with drivers if not using db services" do
    stage :play, {:services=>[]} do |staged_dir|
      jar_present?(staged_dir, "app/lib/#{POSTGRESQL_DRIVER_JAR}").should == false
      jar_present?(staged_dir, "app/lib/#{MYSQL_DRIVER_JAR}").should == false
    end
  end

  it "should have the auto reconfiguration jar in the lib path" do
    stage :play do |staged_dir|
      auto_reconfig_jar_relative_path = "app/lib/#{AUTOSTAGING_JAR}"
      auto_reconfiguration_jar_path = File.join(staged_dir, auto_reconfig_jar_relative_path)
      File.exist?(auto_reconfiguration_jar_path).should == true
    end
  end
end

describe "A Play app that uses postgres being staged" do
  before do
    app_fixture :play_postgres_app
  end

  it "is not packaged with an additional postgres driver" do
    stage :play, {:services=>[{:label=>"postgresql-9.0"}]} do |staged_dir|
      jar_present?(staged_dir, "app/lib/#{POSTGRESQL_DRIVER_JAR}").should == false
      jar_present?(staged_dir, "app/lib/#{MYSQL_DRIVER_JAR}").should == false
    end
  end
end

describe "A Play app that uses mysql being staged" do
  before do
    app_fixture :play_mysql_app
  end

  it "is not packaged with an additional mysql driver" do
    stage :play, {:services=>[{:label=>"mysql-5.1"}]} do |staged_dir|
      jar_present?(staged_dir, "app/lib/#{POSTGRESQL_DRIVER_JAR}").should == false
      jar_present?(staged_dir, "app/lib/#{MYSQL_DRIVER_JAR}").should == false
    end
  end
end
