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

      # FIXME sunset this by Monday, March 5
      # The expected string should really stay hardcoded
      local_bin_path = ENV['VCAP_RUNTIME_RUBY18']? File.dirname(ENV['VCAP_RUNTIME_RUBY18']) : '/usr/bin'

      script_body.should == <<-EXPECTED
#!/bin/bash
export DISABLE_AUTO_CONFIG="mysql:postgresql"
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:#{local_bin_path}:/usr/bin:/bin"
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
if [ -f "$PWD/app/config/database.yml" ] ; then
  cd app && #{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rake db:migrate --trace >>../logs/migration.log 2>> ../logs/migration.log && cd ..;
fi
if [ -n "$VCAP_CONSOLE_PORT" ]; then
  cd app
  #{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} cf-rails-console/rails_console.rb >>../logs/console.log 2>> ../logs/console.log &
  CONSOLE_STARTED=$!
  echo "$CONSOLE_STARTED" >> ../console.pid
  cd ..
fi
cd app
#{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rails server $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
    end
  end

  it "generates an auto-config script" do
     stage :rails3 do |staged_dir|
       auto_stage_script = File.join(staged_dir,'app','config','initializers','01-autoconfig.rb')
       script_body = File.read(auto_stage_script)
       script_body.should == <<-EXPECTED
require 'cfautoconfig'
     EXPECTED
     end
  end

it "installs autoconfig gem" do
     stage :rails3 do |staged_dir|
       gemfile = File.join(staged_dir,'app','Gemfile')
       gemfile_body = File.read(gemfile)
       gemfile_body.should == <<-EXPECTED
source 'http://rubygems.org'

gem 'rails', '3.0.4'

gem "cf-autoconfig"
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
        # FIXME sunset this by Monday, March 5
        # The expected string should really stay hardcoded
        local_bin_path = ENV['VCAP_RUNTIME_RUBY18']? File.dirname(ENV['VCAP_RUNTIME_RUBY18']) : '/usr/bin'

        script_body.should == <<-EXPECTED
#!/bin/bash
export DISABLE_AUTO_CONFIG="mysql:postgresql"
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:#{local_bin_path}:/usr/bin:/bin"
export RACK_ENV="production"
export RAILS_ENV="production"
export RUBYOPT="-I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
if [ -f "$PWD/app/config/database.yml" ] ; then
  cd app && #{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rake db:migrate --trace >>../logs/migration.log 2>> ../logs/migration.log && cd ..;
fi
if [ -n "$VCAP_CONSOLE_PORT" ]; then
  cd app
  #{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} cf-rails-console/rails_console.rb >>../logs/console.log 2>> ../logs/console.log &
  CONSOLE_STARTED=$!
  echo "$CONSOLE_STARTED" >> ../console.pid
  cd ..
fi
cd app
#{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} ./rubygems/ruby/1.8/bin/rails server thin $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
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

  it "receives the rails console" do
    stage :rails3 do |staged_dir|
      plugin_dir = staged_dir.join('app', 'cf-rails-console')
      plugin_dir.should be_directory
      access_file = staged_dir.join('app', 'cf-rails-console','.consoleaccess')
      config = YAML.load_file(access_file)
      config['username'].should_not be_nil
      config['password'].should_not be_nil
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

