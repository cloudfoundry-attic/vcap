#
# Cookbook Name:: postgres service
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"

  /\s*\d*.\d*\s*/ =~ "#{node[:postgresql][:service_version]}"
  pg_major_version = $&.strip
  pg_port = "#{node[:postgresql][:service_port]}"
  cf_pg_install(pg_major_version, pg_port)

else
    Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end

cf_pg_update_hba_conf(node[:postgresql_node][:database], node[:postgresql][:server_root_user], node[:postgresql][:service_version])
cf_pg_setup_db(node[:postgresql_node][:database], node[:postgresql][:server_root_user], node[:postgresql][:server_root_password], true, node[:postgresql][:service_port])
