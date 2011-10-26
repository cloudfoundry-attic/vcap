# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift File.expand_path("../../lib", __FILE__)
require "bundler"
Bundler.require(:default, :spec)

require "vcap/common"
require "vcap/component"
require "vcap/rolling_metric"
require "vcap/json_schema"
require "vcap/subprocess"
require "vcap/process_utils"
require "vcap/config"
require "vcap/priority_queue"

def fixture_path(*args)
  base = File.expand_path("../", __FILE__)
  File.join(base, 'fixtures', *args)
end
