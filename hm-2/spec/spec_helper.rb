# Copyright (c) 2009-2012 VMware, Inc.
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

home = File.join(File.dirname(__FILE__), '..')
ENV['BUNDLE_GEMFILE'] = "#{home}/Gemfile"

require 'rubygems'
require 'rspec'
require 'bundler/setup'

require 'hm-2'

def set_env(name, value)
  @env_stack ||= []
  @env_stack.push(ENV[name])
  ENV[name] = value
end

def restore_env(name)
  ENV[name] = @env_stack.pop
end
