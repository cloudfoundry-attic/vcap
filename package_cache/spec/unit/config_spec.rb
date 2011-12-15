$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'fileutils'
require 'config'

describe VCAP::PackageCache::Config do
  it "should parse a config file" do
    config_file = VCAP::PackageCache::Config::DEFAULT_CONFIG_PATH
    config = VCAP::PackageCache::Config.from_file(config_file)
    config.should_not == nil
  end
end
