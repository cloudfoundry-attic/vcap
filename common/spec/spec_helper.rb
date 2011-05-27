# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift File.expand_path("../../lib", __FILE__)
require "bundler"
Bundler.require(:default, :spec)

require "vcap/common"
require "vcap/component"
require "vcap/rolling_metric"
require "vcap/json_schema"
