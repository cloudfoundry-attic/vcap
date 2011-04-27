require 'spec_helper'

describe "A simple Sinatra app being staged" do
  before do
    app_fixture :sinatra_trivial
  end

  it "is packaged with a startup script" do
    stage :sinatra do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-rubygems -I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
#{executable} app.rb $@ > ../logs/stdout.log 2> ../logs/stderr.log &
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

  describe "when bundled" do
    before do
      app_fixture :sinatra_gemfile
    end

    it "is packaged with a startup script" do
      stage :sinatra do |staged_dir|
        executable = '%VCAP_LOCAL_RUNTIME%'
        start_script = File.join(staged_dir, 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:$PATH"
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
#{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./app.rb $@ > ../logs/stdout.log 2> ../logs/stderr.log &
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
end

