require 'erb'
require 'fileutils'

module VCAP
  module Plugins
    module Staging
    end
  end
end

class VCAP::Plugins::Staging::Sinatra
  ASSET_DIR               = File.expand_path('../../../../../../assets', __FILE__)
  STDSYNC_PATH            = File.join(ASSET_DIR, 'stdsync.rb')
  START_TEMPLATE_PATH     = File.join(ASSET_DIR, 'start.erb')
  STOP_SCRIPT_PATH        = File.join(ASSET_DIR, 'stop')
  DEFAULT_CONFIG_PATH     = File.join(ASSET_DIR, 'config.yml')
  SINATRA_DETECTION_REGEX = /require 'sinatra'|require "sinatra"/

  attr_reader :name

  def initialize(config_path=DEFAULT_CONFIG_PATH)
    @name = 'vcap_sinatra_staging_plugin'
    @ruby_paths = {}
    @start_template = ERB.new(File.read(START_TEMPLATE_PATH))
    configure(config_path)
  end

  def configure(config_path)
    config = YAML.load_file(config_path)
    @ruby_paths = config['ruby_paths']
    unless @ruby_paths
      raise "ruby_paths missing from config at #{config_path}"
    end
  end

  def framework_plugin?
    true
  end

  def should_stage?(app_props)
    app_props['framework'] == 'sinatra'
  end

  def stage(app_root, actions, app_props)
    sinatra_main = find_main_file(app_root)
    unless sinatra_main
      raise "Could not find main file in application root."
    end

    ruby_path = @ruby_paths[app_props['runtime']]
    unless ruby_path
      raise "No ruby executable for runtime #{app_props['runtime']}"
    end

    actions.environment['RUBYOPT'] = '"-I$PWD/ruby -rstdsync"'
    copy_stdsync(actions.droplet_base_dir)
    uses_bundler = File.exist?(File.join(app_root, 'Gemfile.lock'))
    generate_start_script(actions.start_script, File.basename(app_root),
                          sinatra_main, ruby_path, uses_bundler)
    generate_stop_script(actions.stop_script)
  end

  # Finds the first file in the application root that requires sinatra.
  #
  # @param  app_dir  Path to the root of the application's source directory.
  def find_main_file(app_dir)
    for src_file in Dir.glob(File.join(app_dir, '*'))
      next if File.directory?(src_file)
      src_contents = File.read(src_file)
      return File.basename(src_file) if src_contents.match(SINATRA_DETECTION_REGEX)
    end
    nil
  end

  # The file stdsync.rb contains a single line that sets stdout to synchronous mode.
  # The startup script we generate expects it to live at 'DROPLET_ROOT/ruby/stdsync.rb'.
  # Make sure we put it there.
  #
  # @param  base_dir  String  Path to the base of the droplet being created.
  def copy_stdsync(base_dir)
    stdsync_dir = File.join(base_dir, 'ruby')
    stdsync_dst = File.join(stdsync_dir, 'stdsync.rb')
    FileUtils.mkdir(stdsync_dir)
    FileUtils.cp(STDSYNC_PATH, stdsync_dst)
  end

  # Generates the startup script that will be run on the DEA.
  #
  # @param  start_script  File    Open file that will house the start script.
  # @param  app_dir       String  Basename of app dir relative to droplet root
  # @param  sinatra_main  String  Name of 'main' sinatra file.
  # @param  ruby_path     String  Path to ruby executable that should run the application
  # @param  uses_bundler  Bool    Need to use 'bundle exec' to start the app
  def generate_start_script(start_script, app_dir, sinatra_main, ruby_path, uses_bundler)
    contents = @start_template.result(binding())
    start_script.write(contents)
  end

  # Writes out the stop script
  #
  # @param  stop_script  File  Open file that will house the stop script
  def generate_stop_script(stop_script)
    contents = File.read(STOP_SCRIPT_PATH)
    stop_script.write(contents)
  end
end
