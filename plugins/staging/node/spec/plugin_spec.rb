require File.expand_path('../spec_helper', __FILE__)

require 'fileutils'
require 'tmpdir'

describe VCAP::Plugins::Staging::Node do
  describe '#configure' do
    before :each do
      @tmpdir = Dir.mktmpdir
      @config = File.join(@tmpdir, 'config.yml')
      File.open(@config, 'w+') {|f| f.write("test: value") }
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should raise an exception if the config file does not contain a "node_executable" key' do
      plugin = VCAP::Plugins::Staging::Node.new
      expect do
        plugin.configure(@config)
      end.to raise_error(RuntimeError, /node_executable/)
    end
  end

  describe '#find_main_file' do
    before :each do
      @tmpdir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should return the basename of the first matching file' do
      main_file = File.join(@tmpdir, 'main.js')
      FileUtils.touch(main_file)
      plugin = VCAP::Plugins::Staging::Node.new
      plugin.find_main_file(@tmpdir).should == 'main.js'
    end

    it 'should return nil if no matching files were found' do
      plugin = VCAP::Plugins::Staging::Node.new
      plugin.find_main_file(@tmpdir).should be_nil
    end
  end

  describe '#stage' do
    before :each do
      @tmpdir = Dir.mktmpdir
      @app_dir = File.join(@tmpdir, 'app')
      FileUtils.mkdir(@app_dir)
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should call abort_staging if the main file cannot be found' do
      plugin = VCAP::Plugins::Staging::Node.new
      actions = make_stub_actions(@tmpdir)
      actions.should_receive(:abort_staging)
      plugin.stage(@app_dir, actions, nil)
    end

    it 'should create start and stop scripts in the droplet root' do
      main_file = File.join(@app_dir, 'main.js')
      FileUtils.touch(main_file)
      plugin = VCAP::Plugins::Staging::Node.new
      actions = make_stub_actions(@tmpdir)
      plugin.stage(@app_dir, actions, nil)
      File.exist?(actions.start_script.path).should be_true
      File.exist?(actions.stop_script.path).should be_true
    end
  end

  def make_stub_actions(base_dir)
    actions = mock()
    start_script = File.open(File.join(base_dir, 'start'), 'w+')
    actions.stub!(:start_script).and_return(start_script)
    stop_script = File.open(File.join(base_dir, 'stop'), 'w+')
    actions.stub!(:stop_script).and_return(stop_script)
    actions
  end
end
