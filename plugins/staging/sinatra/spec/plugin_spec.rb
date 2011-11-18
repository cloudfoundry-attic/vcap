$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'fileutils'
require 'tmpdir'

require 'vcap/plugins/staging/sinatra'

describe VCAP::Plugins::Staging::Sinatra do
  TEST_ASSETS_DIR = File.expand_path('../../test_assets', __FILE__)

  describe '#find_main_file' do
    before :each do
      @tmpdir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should return nil if it cannot find a ruby file in the root directory that requires sinatra' do
      plugin = VCAP::Plugins::Staging::Sinatra.new
      plugin.find_main_file(@tmpdir).should be_nil
    end

    it 'should detect files that require sinatra using single quotes' do
      copy_test_asset('sinatra_single_quotes.rb', @tmpdir)
      plugin = VCAP::Plugins::Staging::Sinatra.new
      plugin.find_main_file(@tmpdir).should == 'sinatra_single_quotes.rb'
    end

    it 'should detect files that require sinatra using double quotes' do
      copy_test_asset('sinatra_double_quotes.rb', @tmpdir)
      plugin = VCAP::Plugins::Staging::Sinatra.new
      plugin.find_main_file(@tmpdir).should == 'sinatra_double_quotes.rb'
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
      plugin = VCAP::Plugins::Staging::Sinatra.new
      plugin.copy_stdsync(@tmpdir)
      File.exist?(File.join(@tmpdir, 'ruby', 'stdsync.rb')).should be_true
    end
  end

  describe '#stage' do
    before :each do
      @tmpdir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should call abort_staging if it cannot find the main file' do
      plugin = VCAP::Plugins::Staging::Sinatra.new
      actions = mock()
      actions.should_receive(:abort_staging).with(any_args()).and_raise(RuntimeError.new)
      expect do
        plugin.stage(@tmpdir, actions, {'runtime' => 'ruby18'})
      end.to raise_error
    end

    it 'should call abort_staging if it cannot find an executable for the supplied runtime' do
      copy_test_asset('sinatra_single_quotes.rb', @tmpdir)
      plugin = VCAP::Plugins::Staging::Sinatra.new
      actions = mock()
      actions.should_receive(:abort_staging).with(any_args()).and_raise(RuntimeError.new)
      expect do
        plugin.stage(@tmpdir, actions, {'runtime' => 'invalid'})
      end.to raise_error
    end
  end

  def copy_test_asset(asset_name, dst_dir)
    src = File.join(TEST_ASSETS_DIR, asset_name)
    dst = File.join(@tmpdir, asset_name)
    FileUtils.cp(src, dst)
  end
end
