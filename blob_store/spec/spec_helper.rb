ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
Bundler.setup(:default, :test)

require "rack/test"

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

ENV["RACK_ENV"] = "test"

require "blob_store"
require "client"

