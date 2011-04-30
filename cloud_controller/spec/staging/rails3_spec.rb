require 'spec_helper'

describe "A Rails 3 application being staged" do
  it "FIXME doesn't load the schema when there are no migrations"
  it "FIXME doesn't package all the gems if production mode requires git sources"

  before do
    app_fixture :rails3_nodb
  end

  it "is packaged with a startup script" do
    stage :rails3 do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:/usr/bin:/usr/bin:/bin"
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
if [ -f "$PWD/app/config/database.yml" ] ; then
  cd app && #{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rake db:migrate --trace >>../logs/migration.log 2>> ../logs/migration.log && cd ..;
fi
cd app
#{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rails server $@ > ../logs/stdout.log 2> ../logs/stderr.log &
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

  describe "which bundles 'thin'" do
    before do
      app_fixture :rails3_no_assets
    end

    it "is started with `rails server thin`" do
      stage :rails3 do |staged_dir|
        executable = '%VCAP_LOCAL_RUNTIME%'
        start_script = File.join(staged_dir, 'startup')
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:/usr/bin:/usr/bin:/bin"
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
if [ -f "$PWD/app/config/database.yml" ] ; then
  cd app && #{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rake db:migrate --trace >>../logs/migration.log 2>> ../logs/migration.log && cd ..;
fi
cd app
#{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rails server thin $@ > ../logs/stdout.log 2> ../logs/stderr.log &
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

  it "does not receive the static_assets plugin by default" do
    stage :rails3 do |staged_dir|
      plugin_dir = staged_dir.join('app', 'vendor', 'plugins', 'serve_static_assets')
      plugin_dir.should_not be_directory
    end
  end

  describe "which disables static asset support" do
    before do
      app_fixture :rails3_no_assets
    end

    it "is packaged with the appropriate Rails plugin" do
      stage :rails3 do |staged_dir|
        plugin_dir = staged_dir.join('app', 'vendor', 'plugins')
        env = staged_dir.join('app', 'config', 'environments', 'production.rb')
        env_settings = File.open(env) { |f| f.read }
        config = 'config.serve_static_assets = false'
        env_settings.should include(config)
        plugin_dir.join('serve_static_assets').should be_directory
        plugin_dir.join('serve_static_assets', 'init.rb').should be_readable
      end
    end
  end

  describe "which uses git URLs for its test dependencies" do
    before do
      app_fixture :rails3_gitgems
    end

    it "installs the development and production gems" do
      pending
      stage :rails3 do |staged_dir|
        start_script = staged_dir.join('startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        rails = staged_dir.join('app', 'rubygems', 'ruby', '1.8', 'gems', 'rails-3.0.5')
        rails.should be_directory
      end
    end
  end
end

