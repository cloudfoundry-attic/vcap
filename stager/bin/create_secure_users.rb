#!/usr/bin/env ruby
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require 'vcap/stager/secure_user_manager'

VCAP::Stager::SecureUserManager.instance.create_secure_users
