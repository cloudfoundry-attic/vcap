require "spec_helper"

describe "A simple Node.js app being staged" do

  before do
    app_fixture :node_trivial
  end

  it "is packaged with a startup script" do
    stage :node do |staged_dir|
      start_script = File.join(staged_dir, "startup")
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS app.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED
    end
  end

  describe "with a package.json that defines a start script" do
    before do
      app_fixture :node_package
    end

    it "uses it for the start command" do
      stage :node do |staged_dir|
        start_script = File.join(staged_dir, "startup")
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS bin/app.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED
      end
    end
  end

  describe "with a package.json that defines a start script with no 'node '" do
    before do
      app_fixture :node_package_no_exec
    end
    it "uses it for the start command with executable prepended" do
      stage :node do |staged_dir|
        start_script = File.join(staged_dir, "startup")
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS ./bin/app.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED
      end
    end
  end

  describe "with a package.json that does not parse" do
    before do
      app_fixture :node_package_bad
    end

    it "fails and lets the exception propagate" do
      proc {
        stage :node do |staged_dir|
          start_script = File.join(staged_dir, "startup")
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
  #!/bin/bash
  cd app
  %VCAP_LOCAL_RUNTIME% $NODE_ARGS app.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
  STARTED=$!
  echo "$STARTED" >> ../run.pid
  wait $STARTED
  EXPECTED
        end
      }.should raise_error
    end
  end

  describe "with a package.json that does not define a start script" do
    before do
      app_fixture :node_package_no_start
    end

    it "falls back onto normal detection" do
      stage :node do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
cd app
%VCAP_LOCAL_RUNTIME% $NODE_ARGS app.js $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
EXPECTED
      end
    end
  end
end

describe "A Node.js app with dependencies being staged" do

  def node_config
    runtime_staging_config("node", "node")
  end

  # check if node manifest has specified path to npm
  def pending_unless_npm_provided(runtime)
    unless node_config["npm"]
      pending "npm config was not provided in manifest"
    end
  end

  def package_config(package_dir)
    package_config_file = File.join(package_dir, "package.json")
    Yajl::Parser.parse(File.new(package_config_file, "r"))
  end

  def test_package_version(package_dir, version)
    File.exist?(package_dir).should be_true
    package_info = package_config(package_dir)
    package_info["version"].should eql(version)
  end

  describe "with a patched dependency and no shrinkwrap.json" do
    before do
      app_fixture :node_deps_patched
    end

    it "does not overwrite user's module" do
      stage :node do |staged_dir|
        pending_unless_npm_provided("node")
        patched_file = File.join(staged_dir, "app", "node_modules", "colors", "patched.js")
        File.exists?(patched_file).should be_true
      end
    end
  end

  describe "with a patched dependency and shrinkwrap" do
    before do
      app_fixture :node_deps_installed
    end

    it "does not overwrite user's module" do
      stage :node do |staged_dir|
        pending_unless_npm_provided("node")
        patched_file = File.join(staged_dir, "app", "node_modules", "colors", "patched.js")
        File.exists?(patched_file).should be_true
      end
    end
  end

  describe "with shrinkwrap and no node module" do
    before do
      app_fixture :node_deps_shrinkwrap
    end

    it "module will be installed with version specified in shrinkwrap" do
      stage :node do |staged_dir|
        pending_unless_npm_provided("node")
        package_dir = File.join(staged_dir, "app", "node_modules", "colors")
        File.exists?(package_dir).should be_true
        package_info = package_config(package_dir)
        package_info["version"].should eql("0.5.0")
      end
    end
  end

  describe "with shrinkwrap, node module and cloudfoundry.json" do
    before do
      app_fixture :node_deps_ignore
    end

    it "module will be overwritten with version specified in shrinkwrap" do
      stage :node do |staged_dir|
        pending_unless_npm_provided("node")
        package_dir = File.join(staged_dir, "app", "node_modules", "colors")
        patched_file = File.join(package_dir, "patched.js")
        File.exists?(patched_file).should_not be_true
        package_info = package_config(package_dir)
        package_info["version"].should eql("0.5.0")
      end
    end

    it "uses cache" do
      cached_package = File.join(StagingPlugin.platform_config["cache"],
                                 "node_modules/04/npm_cache/colors/0.5.0/package")
      pending "this test depends on the previous" unless File.exists?(cached_package)
      patched_cache_file = File.join(cached_package, "cached.js")
      FileUtils.touch(patched_cache_file)
      stage :node do |staged_dir|
        pending_unless_npm_provided("node")
        package_dir = File.join(staged_dir, "app", "node_modules", "colors")
        cached_file = File.join(package_dir, "cached.js")
        File.exists?(cached_file).should be_true
      end
    end
  end

  describe "with native dependencies" do
    before do
      app_fixture :node_deps_native
    end

    it "module will be rebuild" do
      stage :node do |staged_dir|
        pending_unless_npm_provided("node")
        package_dir = File.join(staged_dir, "app", "node_modules", "bcrypt")
        built_package = File.join(package_dir, "build", "Release", "bcrypt_lib.node")
        File.exist?(built_package).should be_true
      end
    end
  end

  describe "with a shrinkwrap tree" do
    before do
      app_fixture :node_deps_tree
    end

    it "install modules according to tree" do
      stage :node do |staged_dir|
        pending_unless_npm_provided("node")
        app_level = File.join(staged_dir, "app", "node_modules")
        colors = File.join(app_level, "colors")
        test_package_version(colors, "0.5.0")
        mime = File.join(colors, "node_modules", "mime")
        test_package_version(mime, "1.2.4")
        test_package_version(File.join(mime, "node_modules", "colors"), "0.6.0")
        test_package_version(File.join(mime, "node_modules", "async_testing"), "0.3.2")

        express = File.join(app_level, "express")
        test_package_version(express, "2.5.9")
        express_modules = File.join(express, "node_modules")
        connect = File.join(express_modules, "connect")
        test_package_version(connect, "1.8.7")
        test_package_version(File.join(connect, "node_modules", "formidable"), "1.0.9")
        test_package_version(File.join(express_modules, "mime"), "1.2.4")
        test_package_version(File.join(express_modules, "qs"), "0.4.2")
        test_package_version(File.join(express_modules, "mkdirp"), "0.3.0")
      end
    end
  end

end
