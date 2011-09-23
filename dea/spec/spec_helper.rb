# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift File.join(File.dirname(__FILE__), '..')
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')


home = File.join(File.dirname(__FILE__), '/..')
ENV['BUNDLE_GEMFILE'] = "#{home}/Gemfile"

require 'rubygems'
require 'rspec'
require 'bundler/setup'

require 'vcap/logging'

VCAP::Logging.setup_from_config({:level => :debug2}) if ENV['VCAP_TEST_LOG'] == 'true'
