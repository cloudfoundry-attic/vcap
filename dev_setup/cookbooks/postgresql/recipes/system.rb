#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#

case node['platform']
when "ubuntu"

  /\s*\d*.\d*\s*/ =~ "#{node[:postgresql][:system_version]}"
  pg_major_version = $&.strip
  pg_port = "#{node[:postgresql][:system_port]}"
  cf_pg_install(pg_major_version, pg_port)

else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end
