$:.unshift(File.dirname(__FILE__))
require 'spec_helper'
require 'fileutils'
require 'config'

describe VCAP::PackageCacheClient::Config do
  it "should parse a config file" do
    config_file = VCAP::PackageCacheClient::Config::DEFAULT_CONFIG_PATH
    config = VCAP::PackageCacheClient::Config.from_file(config_file)
    config.should_not == nil
  end
end
