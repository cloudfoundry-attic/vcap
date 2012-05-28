#
# Cookbook Name:: uaadb
# Recipe:: default
#
# Copyright 2011, VMware
#
#

cf_pg_reset_user_password(:uaadb)
cf_pg_update_hba_conf(node[:uaadb][:database], node[:uaadb][:user], node[:postgresql][:system_version])
cf_pg_setup_db(node[:uaadb][:database], node[:uaadb][:user], node[:uaadb][:password], node[:uaadb][:adapter] == 'postgresql' && node[:postgresql][:system_version] == node[:postgresql][:service_version] && node[:postgresql][:system_port] == node[:postgresql][:system_port], node[:postgresql][:system_port])
