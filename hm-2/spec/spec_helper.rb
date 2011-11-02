# Copyright (c) 2009-2012 VMware, Inc.
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

home = File.join(File.dirname(__FILE__), '..')
ENV['BUNDLE_GEMFILE'] = "#{home}/Gemfile"

require 'rubygems'
require 'rspec'
require 'bundler/setup'

require 'hm2'
