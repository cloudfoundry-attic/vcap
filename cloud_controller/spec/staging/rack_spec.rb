require 'spec_helper'

describe "A simple Rack app being staged" do
  before do
    app_fixture :rack_trivial
  end

  it "is packaged with a startup script" do
    stage :rack do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      gem_bin_dir = "./rubygems/ruby/1.8/bin"
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
#{executable} -S bundle exec #{gem_bin_dir}/thin -R config.ru $@ start > ../logs/stdout.log 2> ../logs/stderr.log &
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

describe "A simple Rack app with no Gemfile failing to be staged" do
  before do
    app_fixture :rack_no_gemfile
  end

  it "fails with an exception if there is no Gemfile" do
    lambda {
      stage :rack do |staged_dir|
        executable = '%VCAP_LOCAL_RUNTIME%'
        start_script = File.join(staged_dir, 'startup')
        gem_bin_dir = "./rubygems/ruby/1.8/bin"
        start_script.should be_executable_file
      end
    }.should raise_exception(RuntimeError)
  end
end
