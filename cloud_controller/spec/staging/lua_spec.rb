require 'spec_helper'

describe "A simple Lua app being staged" do
  before do
    app_fixture :lua_trivial
  end

  it "is packaged with a startup script" do
    stage :lua do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
mkdir cnf
echo "port = os.getenv('VMC_APP_PORT')" >> ./cnf/wsapi.conf
cd app
wsapi -c ./cnf/wsapi.conf > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
echo "#!/bin/bash" >> ../stop
echo "kill -9 $STARTED" >> ../stop
echo "kill -9 $PPID" >> ../stop
chmod 755 ../stop
wait $STARTED
      EXPECTED
    end
  end
end

