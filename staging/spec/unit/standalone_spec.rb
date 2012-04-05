require 'spec_helper'

describe "A Standalone app being staged" do

   describe "when bundled" do
    before do
      app_fixture :standalone_gemfile
    end

    describe "and using Ruby 1.8" do
      it "is packaged with a startup script" do
        stage(:standalone,{:meta=>{:command=> "ruby app.rb"}, :runtime=> "ruby18"}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:$PATH"
export RUBYOPT="-I$PWD/ruby -I$PWD/app/rubygems/ruby/1.8/gems/cf-autoconfig-0.0.2/lib -rcfautoconfig -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby app.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
        EXPECTED
        end
      end
      it "installs gems" do
        stage(:standalone,{:meta=>{:command=> "ruby app.rb"}, :runtime=> "ruby18"}) do |staged_dir|
          gemdir = File.join(staged_dir,'app','rubygems','ruby','1.8')
          Dir.entries(gemdir).should_not == []
        end
      end
      it "installs autoconfig gem" do
       stage :sinatra do |staged_dir|
         gemfile = File.join(staged_dir,'app','Gemfile')
         gemfile_body = File.read(gemfile)
         gemfile_body.should == <<-EXPECTED
source "http://rubygems.org"
gem "sinatra"
gem "thin"
gem "json"

gem "cf-autoconfig"
         EXPECTED
       end
     end
    end
    describe "and using Ruby 1.9" do
      it "is packaged with a startup script" do
        stage(:standalone,{:meta=>{:command=> "ruby app.rb"}, :runtime=> "ruby19"}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.9.1"
export GEM_PATH="$PWD/app/rubygems/ruby/1.9.1"
export PATH="$PWD/app/rubygems/ruby/1.9.1/bin:$PATH"
export RUBYOPT="-I$PWD/ruby  -rcfautoconfig -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby app.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
        EXPECTED
        end
      end
      it "installs gems" do
        stage(:standalone,{:meta=>{:command=> "ruby app.rb"}, :runtime=> "ruby19"}) do |staged_dir|
          gemdir = File.join(staged_dir,'app','rubygems','ruby','1.9.1')
          Dir.entries(gemdir).should_not == []
        end
      end
      it "installs autoconfig gem" do
       stage :sinatra do |staged_dir|
         gemfile = File.join(staged_dir,'app','Gemfile')
         gemfile_body = File.read(gemfile)
         gemfile_body.should == <<-EXPECTED
source "http://rubygems.org"
gem "sinatra"
gem "thin"
gem "json"

gem "cf-autoconfig"
         EXPECTED
       end
     end
    end
  end

  describe "when using Ruby and not bundled" do
    before do
      app_fixture :standalone_simple_ruby
    end

    describe "and using Ruby 1.8" do
      it "is packaged with a startup script" do
        stage(:standalone,{:meta=>{:command=> "ruby hello.rb"}, :runtime=> "ruby18"}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export RUBYOPT="-rubygems -I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby hello.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
      end
    end
    describe "and using Ruby 1.9" do
      it "is packaged with a startup script" do
        stage(:standalone,{:meta=>{:command=> "ruby hello.rb"}, :runtime=> "ruby19"}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export RUBYOPT="-rubygems -I$PWD/ruby -rstdsync"
unset BUNDLE_GEMFILE
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
ruby hello.rb > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
      end
    end
  end

  describe "with Java runtime" do
    before do
      app_fixture :standalone_java
    end
    it "is packaged with a startup script" do
      stage(:standalone,{:meta=>{:command=> "java $JAVA_OPTS HelloWorld"}, :runtime=> "java", :environment=>{:resources=>{:memory=>512}}}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export JAVA_OPTS="$JAVA_OPTS -Xms512m -Xmx512m -Djava.io.tmpdir=$PWD/temp"
cd app
java $JAVA_OPTS HelloWorld > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
    end
    it "creates a temp dir" do
      stage(:standalone,{:meta=>{:command=> "java $JAVA_OPTS HelloWorld"}, :runtime=> "java", :environment=>{:resources=>{:memory=>512}}}) do |staged_dir|
          tmp_dir = File.join(staged_dir, 'temp')
          File.exists?(tmp_dir).should == true
        end
    end
  end

  describe "with Python runtime" do
    before do
      app_fixture :standalone_python
    end
    it "is packaged with a startup script" do
      stage(:standalone,{:meta=>{:command=> "python HelloWorld.py"}, :runtime=> "python2", :environment=>{:resources=>{:memory=>512}}}) do |staged_dir|
          start_script = File.join(staged_dir, 'startup')
          start_script.should be_executable_file
          script_body = File.read(start_script)
          script_body.should == <<-EXPECTED
#!/bin/bash
export PYTHONUNBUFFERED="true"
cd app
python HelloWorld.py > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
          EXPECTED
        end
    end
  end
end
