$:.unshift(File.join(File.dirname(__FILE__)))
require 'rubygems'
require 'server'
run PackageCache::PackageCacheApi.new
