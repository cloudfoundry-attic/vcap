#!/usr/bin/env ruby
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'rubygems'
require 'bundler/setup'

require 'yajl'

require 'vcap/staging/plugin/common'

unless ARGV.length > 0
  puts "Usage: run_plugin.rb [plugin name] [plugin args]"
  exit 1
end

name = ARGV.shift
args = ARGV.dup

if args.length > 2
  begin
    File.open(args[2], "r") { |f|
      env_json = f.read
      args[2] = Yajl::Parser.parse(env_json, :symbolize_keys => true)
    }
  rescue => e
    puts "ERROR DECODING ENVIRONMENT: #{e}"
    exit 1
  end
end

plugin_class = StagingPlugin.load_plugin_for(name)
plugin_class.validate_arguments!(*args)
plugin_class.new(*args).stage_application
