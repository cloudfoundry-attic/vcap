require 'spec_helper'

describe "A simple Node.js app being staged" do
  before do
    app_fixture :node_trivial
  end

  it "is packaged with a startup script" do
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

  describe "with a package.json that defines a start script" do
    before do
      app_fixture :node_package
    end

    it "uses it for the start command" do
      stage :node do |staged_dir|
        start_script = File.join(staged_dir, 'startup')
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
        start_script = File.join(staged_dir, 'startup')
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

