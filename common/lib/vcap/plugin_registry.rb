require 'vcap/logging'

module VCAP
  class PluginRegistry
    class << self
      attr_accessor :plugin_config_dir
      attr_accessor :plugins

      def plugins
        @plugins ||= {}
        @plugins
      end

      # Registers a set of plugins with the system. Plugins should call this method
      # when their export file is required.
      def register_plugins(*plugins)
        @plugins ||= {}
        logger = VCAP::Logging.logger('vcap.plugins.registry')
        plugins.each do |plugin|
          logger.debug("Registering plugin '#{plugin.name}'")
          @plugins[plugin.name] = plugin
        end
      end

      # Configures registered plugins
      #
      # NB: The contract exposed here is that a plugin's config filename
      #     is of the form '<plugin_name>.yml'.
      def configure_plugins
        return unless @plugin_config_dir
        logger = VCAP::Logging.logger('vcap.plugins.registry')

        config_glob = File.join(@plugin_config_dir, "*.yml")
        logger.debug("Looking for plugin configs using the glob '#{config_glob}'")
        config_paths = Dir.glob(config_glob)

        logger.debug("Found #{config_paths.length} configs")
        for config_path in config_paths
          plugin_name = File.basename(config_path, '.yml')
          plugin = @plugins[plugin_name]
          if plugin
            plugin.configure(config_path)
          else
            logger.warn("No plugin found for config at '#{config_path}'")
          end
        end
      end

    end # << self
  end   # VCAP::PluginRegistry
end     # VCAP
