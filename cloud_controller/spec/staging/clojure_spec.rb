require 'spec_helper'

describe "A simple clojure app being staged" do
  before do
    app_fixture :clojure_trivial
  end

  it "is packaged with a startup script" do
    stage :clojure do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
cd app
export HOME=`pwd`
export PORT=$VCAP_APP_PORT 
#{executable} run $@ > ../logs/stdout.log 2> ../logs/stderr.log &
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

