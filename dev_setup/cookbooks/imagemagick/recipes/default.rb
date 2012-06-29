# Cookbook Name:: imagemagick
# Recipe:: default
#
# Copyright 2012, VMware
#

case node['platform']
when "ubuntu"

  %w[ imagemagick libmagickcore-dev libmagickwand-dev ].each {|pkg| package pkg }

else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end
