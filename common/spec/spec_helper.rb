# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift File.expand_path("../../lib", __FILE__)
$:.unshift File.expand_path("../../lib/vcap/user_pools", __FILE__)
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
require 'vcap/quota'
require 'benchmark'

RSpec::Matchers.define :take_less_than do |n|
  chain :seconds do; end
  match do |block|
    @elapsed = Benchmark.realtime do
      block.call
    end
    @elapsed <= n
  end
end

RSpec.configure do |c|
  # declare an exclusion filter
  if Process.uid != 0
    c.filter_run_excluding :needs_root => true
  end

  unless ENV['QUOTA_TEST_USER'] && ENV['QUOTA_TEST_FS']
    c.filter_run_excluding :needs_quota => true
  end
end

def fixture_path(*args)
  base = File.expand_path("../", __FILE__)
  File.join(base, 'fixtures', *args)
end
