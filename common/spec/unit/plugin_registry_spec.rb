require File.expand_path('../../spec_helper', __FILE__)

require 'fileutils'
require 'tmpdir'

describe VCAP::PluginRegistry do
  describe '.register_plugins' do
    before :each do
      VCAP::PluginRegistry.plugins = {}
    end

    it 'should allow registration of multiple plugins' do
      plugins = [stub_plugin('a'), stub_plugin('b')]
      VCAP::PluginRegistry.register_plugins(*plugins)
      for plugin in plugins
        VCAP::PluginRegistry.plugins[plugin.name].should == plugin
      end
    end

    it 'should only allow one plugin per name' do
      VCAP::PluginRegistry.register_plugins(stub_plugin('a'))
      plugin = stub_plugin('a')
      VCAP::PluginRegistry.register_plugins(plugin)
      VCAP::PluginRegistry.plugins['a'].should == plugin
    end
  end

  describe '.configured_plugins' do
    before :each do
      @tmpdir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should call configure() on the appropriate plugin with the correct path' do
      for name in ['a', 'b']
        plugin = stub_plugin(name)
        config_file = File.join(@tmpdir, "#{name}.yml")
        FileUtils.touch(config_file)
        plugin.should_receive(:configure).with(config_file)
        VCAP::PluginRegistry.register_plugins(plugin)
      end
      VCAP::PluginRegistry.plugin_config_dir = @tmpdir
      VCAP::PluginRegistry.configure_plugins()
    end
  end

  def stub_plugin(name)
    plugin = mock(name)
    plugin.stub!(:name).and_return(name)
    plugin
  end
end
