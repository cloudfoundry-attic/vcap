require 'spec_helper'

describe "A .Net minimal application being staged" do
  before do
    app_fixture :dot_net_test_minimal
  end

  it "is packaged with a startup file with plugin information" do
    stage :dotNet do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      webapp_root = staged_dir.join('app')
      webapp_root.should be_directory
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
    Uhuru.CloudFoundry.DEA.Plugins.dll
    Uhuru.CloudFoundry.DEA.Plugins.IISPlugin
EXPECTED
    end
  end
end

describe "A default VS 2010 ASP.NET template app" do
  before do
    app_fixture :dot_net_test
  end

  it "is packaged with a startup file with plugin information" do
    stage :dotNet do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      webapp_root = staged_dir.join('app')
      webapp_root.should be_directory
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
    Uhuru.CloudFoundry.DEA.Plugins.dll
    Uhuru.CloudFoundry.DEA.Plugins.IISPlugin
EXPECTED
    end
  end
end
