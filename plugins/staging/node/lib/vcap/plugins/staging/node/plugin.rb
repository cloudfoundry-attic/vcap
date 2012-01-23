require 'erb'
require 'set'
require 'yaml'

module VCAP
  module Plugins
    module Staging
    end
  end
end

class VCAP::Plugins::Staging::Node
  ASSET_DIR             = File.expand_path('../../../../../../assets', __FILE__)
  DEFAULT_CONFIG_PATH   = File.join(ASSET_DIR, 'config.yml')
  STARTUP_TEMPLATE_PATH = File.join(ASSET_DIR, 'startup.erb')
  STOP_SCRIPT_PATH      = File.join(ASSET_DIR, 'stop')
  MAIN_FILES            = Set.new(['server.js', 'app.js', 'index.js', 'main.js', 'application.js'])

  attr_reader :framework
  attr_reader :name

  def initialize(config_path=DEFAULT_CONFIG_PATH)
    @framework = 'node'
    @name = 'vcap_node_staging_plugin'
    @node_path = nil
    @startup_template = ERB.new(File.read(STARTUP_TEMPLATE_PATH))
    configure(config_path)
  end

  def configure(config_path)
    config = YAML.load_file(config_path)
    @node_executable = config['node_executable']
    unless @node_executable
      raise "node_executable missing from config at #{config_path}"
    end
  end

  def stage(app_root, actions, app_props)
    main_file = find_main_file(app_root)
    unless main_file
      raise "Could not find main file in application root."
    end
    app_dir = File.basename(app_root)
    write_start_script(actions.start_script, app_dir, main_file, @node_executable)
    write_stop_script(actions.stop_script)
  end

  # Writes out the startup script that will be invoked by the DEA
  #
  # @param  start_script  File
  def write_start_script(start_script, app_dir, main_file, node_executable)
    contents = @startup_template.result(binding())
    start_script.write(contents)
  end

  # Writes out the stop script that will be invoked by the DEA
  #
  # @param  stop_script  File
  def write_stop_script(stop_script)
    contents = File.read(STOP_SCRIPT_PATH)
    stop_script.write(contents)
  end

  # Returns the first file ending in '.js' that belongs to MAIN_FILES.
  #
  # @param  app_root  String  Absolute path to the application root
  #
  # @return String            One of MAIN_FILES if any were found, otherwise nil
  def find_main_file(app_root)
    main_file  = nil
    js_files   = Dir.glob(File.join(app_root, '*.js'))

    for js_file in js_files
      js_base = File.basename(js_file)
      if MAIN_FILES.include?(js_base)
        main_file = js_base
        break
      end
    end

    main_file
  end
end
