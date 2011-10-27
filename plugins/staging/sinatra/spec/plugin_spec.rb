$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'fileutils'
require 'tmpdir'

require 'vcap/plugins/staging/sinatra_staging_plugin'

describe VCAP::Plugins::Staging::SinatraStagingPlugin do
  TEST_ASSETS_DIR = File.expand_path('../../test_assets', __FILE__)

  describe '#find_main_file' do
    before :each do
      @tmpdir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should return nil if it cannot find a ruby file in the root directory that requires sinatra' do
      plugin = VCAP::Plugins::Staging::SinatraStagingPlugin.new
      plugin.send(:find_main_file, @tmpdir).should be_nil
    end

    it 'should detect files that require sinatra using single quotes' do
      copy_test_asset('sinatra_single_quotes.rb', @tmpdir)
      plugin = VCAP::Plugins::Staging::SinatraStagingPlugin.new
      plugin.send(:find_main_file, @tmpdir).should == 'sinatra_single_quotes.rb'
    end

    it 'should detect files that require sinatra using double quotes' do
      copy_test_asset('sinatra_double_quotes.rb', @tmpdir)
      plugin = VCAP::Plugins::Staging::SinatraStagingPlugin.new
      plugin.send(:find_main_file, @tmpdir).should == 'sinatra_double_quotes.rb'
    end
  end

  describe '#copy_stdsync' do
    before :each do
      @tmpdir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should copy stdsync.rb to ruby/stdsync.rb in the droplet root' do
      plugin = VCAP::Plugins::Staging::SinatraStagingPlugin.new
      plugin.send(:copy_stdsync, @tmpdir)
      File.exist?(File.join(@tmpdir, 'ruby', 'stdsync.rb')).should be_true
    end
  end

  describe '#generate_start_script' do
    before :each do
      @tmpdir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    # Not sure about the best way to test this. We're really just checking that
    # the correct block of the if statement is executed in the startup script template...
    it 'should use bundle to start the app if it includes a Gemfile.lock' do
      copy_test_asset('sinatra_single_quotes.rb', @tmpdir)
      File.open(File.join(@tmpdir, 'Gemfile.lock'), 'w+') {|f| f.write('foo') }
      plugin = VCAP::Plugins::Staging::SinatraStagingPlugin.new
      start_script = StringIO.new
      props = mock(:props)
      props.should_receive(:runtime).and_return('ruby19')
      plugin.send(:generate_start_script, start_script, @tmpdir, 'sinatra_single_quotes.rb', props)
      start_script.rewind
      script_contents = start_script.read
      script_contents.match('bundle exec').should be_true
    end

    it 'start the app directly if no Gemfile.lock is included' do
      copy_test_asset('sinatra_single_quotes.rb', @tmpdir)
      plugin = VCAP::Plugins::Staging::SinatraStagingPlugin.new
      start_script = StringIO.new
      props = mock(:props)
      props.should_receive(:runtime).and_return('ruby19')
      plugin.send(:generate_start_script, start_script, @tmpdir, 'sinatra_single_quotes.rb', props)
      start_script.rewind
      script_contents = start_script.read
      script_contents.match('bundle exec').should be_false
    end
  end

  def copy_test_asset(asset_name, dst_dir)
    src = File.join(TEST_ASSETS_DIR, asset_name)
    dst = File.join(@tmpdir, asset_name)
    FileUtils.cp(src, dst)
  end
end
