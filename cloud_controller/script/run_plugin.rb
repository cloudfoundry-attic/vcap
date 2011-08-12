#!/usr/bin/env ruby
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'rubygems'
require 'bundler/setup'

require 'vcap/staging/plugin/common'

unless ARGV.length > 0
  puts "Usage: run_plugin.rb [plugin name] [plugin args]"
  exit 1
end

name = ARGV.shift
plugin_class = StagingPlugin.load_plugin_for(name)
plugin_class.validate_arguments!
plugin_class.new(*ARGV).stage_application
