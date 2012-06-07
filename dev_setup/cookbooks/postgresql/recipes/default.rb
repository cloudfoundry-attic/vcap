#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#

if node[:postgresql][:system_version] != node[:postgresql][:service_version] && node[:postgresql][:system_port] == node[:postgresql][:service_port]
  Chef::Log.error("Different versions of postgresql will be installed, but they should listen different ports")
  exit 1
else
  if node[:postgresql][:system_version] == node[:postgresql][:service_version] && node[:postgresql][:system_port] != node[:postgresql][:service_port]
    Chef::Log.error("Fail to listen on differnt ports using the same  postgresql for diffrent components")
    exit 1
  end
end

case node['platform']
when "ubuntu"

  %w[python-software-properties postgresql-common postgresql-client-common libpq-dev].each do |pkg|
    package pkg
  end

else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end
