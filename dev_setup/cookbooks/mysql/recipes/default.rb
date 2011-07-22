#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
# All rights reserved - Do Not Redistribute
#

case node['platform']
when "ubuntu"
  package "mysql-client"
else
  Chef::Log.error("Installation of mysql client not supported on this platform.")
end
