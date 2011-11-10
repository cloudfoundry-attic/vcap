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
      VCAP::PluginRegistry.plugins = {}
    end

    after :each do
      FileUtils.rm_rf(@src_dir)
      FileUtils.rm_rf(@dst_dir)
    end

    it 'should raise an error for unknown plugins' do
      @app_props['plugins']['unknown'] = {}
      orch = VCAP::Stager::PluginRunner.new(@src_dir, @dst_dir, @app_props, @cc_info)
      expect do
        orch.run_plugins
      end.to raise_error(VCAP::Stager::UnsupportedPluginError)
    end

    it 'should raise an error if no framework plugin is supplied' do
      orch = VCAP::Stager::PluginRunner.new(@src_dir, @dst_dir, @app_props, @cc_info)
      expect do
        orch.run_plugins
      end.to raise_error(VCAP::Stager::MissingFrameworkPluginError)
    end

    it 'should raise an error if > 1 framework plugins are supplied' do
      plugins = []
      2.times do |i|
        name = "plugin_#{i}"
        @app_props['plugins'][name] = {}
        p = create_mock_plugin(name, :framework)
        VCAP::PluginRegistry.register_plugins(p)
      end
      orch  = VCAP::Stager::PluginRunner.new(@src_dir, @dst_dir, @app_props, @cc_info)
      expect do
        orch.run_plugins
      end.to raise_error(VCAP::Stager::DuplicateFrameworkPluginError)
     end

    it 'should raise an error if a plugin of unknown type is supplied' do
      p = create_mock_plugin('plugin0', :invalid_plugin_type)
      VCAP::PluginRegistry.register_plugins(p)
      @app_props['plugins']['plugin0'] = {}
      orch = VCAP::Stager::PluginRunner.new(@src_dir, @dst_dir, @app_props, @cc_info)
      expect do
        orch.run_plugins
      end.to raise_error(VCAP::Stager::UnknownPluginTypeError)
    end

    it 'should call stage on each of the registered plugins' do
      plugin_types = [:framework, :feature, :feature]
      plugin_types.each_with_index do |ptype, ii|
        name = "plugin_#{ii}"
        @app_props['plugins'][name] = {}
        p = create_mock_plugin(name, ptype)
        p.should_receive(:stage).with(any_args())
        VCAP::PluginRegistry.register_plugins(p)
      end
      orch = VCAP::Stager::PluginRunner.new(@src_dir, @dst_dir, @app_props, @cc_info)
      orch.run_plugins
    end
  end

  def create_mock_plugin(name, type)
    ret = mock(name)
    ret.stub(:staging_plugin_type).and_return(type)
    ret.stub(:name).and_return(name)
    ret
  end
end
