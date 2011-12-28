require 'spec_helper'

describe "A Perl application being staged"
    before do
        app_fixture :perl_version
    end
  it "is packaged with a startup script" do
    stage :perl do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      webapp_root = staged_dir.join('app')
      webapp_root.should be_directory
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
env > env.log
bash ./start.sh > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
    end
  end

end
