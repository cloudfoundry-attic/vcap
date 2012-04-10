$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../lib/vcap/package_cache_client')))
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../../common/lib')))
require 'rubygems'
require 'fileutils'
require 'rspec/core'
require 'rspec/expectations'
