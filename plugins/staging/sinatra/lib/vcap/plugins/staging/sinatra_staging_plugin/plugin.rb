require 'erb'
require 'fileutils'

module VCAP
  module Plugins
    module Staging
      class SinatraStagingPluginError < StandardError; end
    end
  end
end

class VCAP::Plugins::Staging::SinatraStagingPlugin
  ASSET_DIR               = File.expand_path('../../../../../../assets', __FILE__)
  STDSYNC_PATH            = File.join(ASSET_DIR, 'stdsync.rb')
  START_TEMPLATE_PATH     = File.join(ASSET_DIR, 'start.erb')
  SINATRA_DETECTION_REGEX = /require 'sinatra'|require "sinatra"/

  attr_reader :name, :plugin_type

  def initialize
    @name = 'vcap_sinatra_plugin'
    @plugin_type = :framework
  end

  def stage(app_dir, actions, app_properties)
    sinatra_main = find_main_file(app_dir)
    raise VCAP::Plugins::Staging::SinatraStagingPluginError, "Couldn't find main file" unless sinatra_main
    copy_stdsync(actions.droplet_base_dir)
    generate_start_script(actions.start_script, app_dir, sinatra_main, app_properties)
  end

  private

  # Finds the first file in the application root that requires sinatra.
  #
  # @param  app_dir  Path to the root of the application's source directory.
  def find_main_file(app_dir)
    for src_file in Dir.glob(File.join(app_dir, '*'))
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
  # @param  start_script  File                         Open file that will house the start script.
  # @param  source_dir    String                       Path to application source
  # @param  sinatra_main  String                       Name of 'main' sinatra file.
  # @param  app_props     VCAP::Stager::AppProperties  Properties of app being staged.
  def generate_start_script(start_script, source_dir, sinatra_main, app_props)
    # Template vars
    if app_props.runtime == 'ruby19'
      library_version = '1.9.1'
    else
      library_version = '1.8'
    end
    uses_bundler = File.exists?(File.join(source_dir, 'Gemfile.lock'))

    template = ERB.new(File.read(START_TEMPLATE_PATH))
    start_script.write(template.result(binding))
  end
end
