require File.join(File.dirname(__FILE__), 'spec_helper')

require 'fileutils'
require 'tmpdir'

describe VCAP::Stager::PluginRunner do
  describe '#run_plugins' do
    before :each do
      @src_dir = Dir.mktmpdir
      @dst_dir = Dir.mktmpdir
      @cc_info = {
        'host'    => '127.0.0.1',
        'port'    => 9090,
        'task_id' => 'test_task_id',
      }
      @app_props = {
        'id'               => 1,
        'name'             => 'testapp',
        'framework'        => 'sinatra',
        'runtime'          => 'ruby18',
        'plugins'          => {},
        'service_configs'  => [],
        'service_bindings' => [],
        'resource_limits'  => {
          'memory' => 128,
          'disk'   => 2048,
          'fds'    => 1024,
        }
      }
    end

    after :each do
      FileUtils.rm_rf(@src_dir)
      FileUtils.rm_rf(@dst_dir)
    end

    it 'should raise an error for unknown plugins' do
      @app_props['plugins']['unknown'] = {}
      runner = VCAP::Stager::PluginRunner.new
      expect do
        runner.run_plugins(@src_dir, @dst_dir, @app_props, @cc_info)
      end.to raise_error(VCAP::Stager::UnsupportedPluginError)
    end

    it 'should raise an error if no framework plugin is supplied' do
      runner = VCAP::Stager::PluginRunner.new
      expect do
        runner.run_plugins(@src_dir, @dst_dir, @app_props, @cc_info)
      end.to raise_error(VCAP::Stager::MissingFrameworkPluginError)
    end

    it 'should raise an error if > 1 framework plugins are supplied' do
      frameworks = ['sinatra', 'unknown']
      plugins = {}
      2.times do |i|
        name = "plugin_#{i}"
        @app_props['plugins'][name] = {}
        plugins[name] = create_mock_plugin(name, frameworks[i])
      end
      runner  = VCAP::Stager::PluginRunner.new(plugins)
      expect do
        runner.run_plugins(@src_dir, @dst_dir, @app_props, @cc_info)
      end.to raise_error(VCAP::Stager::DuplicateFrameworkPluginError)
     end

    it 'should call stage on each of the registered plugins' do
      plugins = {}
      frameworks = ['sinatra', nil, nil]
      frameworks.each_with_index do |framework, ii|
        name = "plugin_#{ii}"
        @app_props['plugins'][name] = {}
        p = create_mock_plugin(name, framework)
        p.should_receive(:stage).with(any_args())
        plugins[name] = p
      end
      runner = VCAP::Stager::PluginRunner.new(plugins)
      runner.run_plugins(@src_dir, @dst_dir, @app_props, @cc_info)
    end
  end

  def create_mock_plugin(name, framework=nil)
    ret = mock()
    ret.stub(:name).and_return(name)
    ret.stub(:framework).and_return(framework) if framework
    ret
  end
end
