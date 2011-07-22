#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"
  package "mysql-client"
else
  Chef::Log.error("Installation of mysql client not supported on this platform.")
end
