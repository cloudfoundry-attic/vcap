#
# Cookbook Name:: uaadb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
unless node[:uaadb][:adapter] != "postgresql"
  # override the postgresql's user and password
  node[:uaadb][:user] = node[:postgresql][:server_root_user]
  node[:uaadb][:password] = node[:postgresql][:server_root_password]
end

cf_pg_update_hba_conf(node[:uaadb][:database], node[:uaadb][:user])
cf_pg_setup_db(node[:uaadb][:database], node[:uaadb][:user], node[:uaadb][:password], node[:uaadb][:adapter] == 'postgresql')
