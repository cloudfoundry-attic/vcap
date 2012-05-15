#
# Cookbook Name:: ccdb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
unless node[:ccdb][:adapter] != "postgresql"
  # override the postgresql's user and password
  node[:ccdb][:user] = node[:postgresql][:server_root_user]
  node[:ccdb][:password] = node[:postgresql][:server_root_password]
end
cf_pg_update_hba_conf(node[:ccdb][:database], node[:ccdb][:user])
cf_pg_setup_db(node[:ccdb][:database], node[:ccdb][:user], node[:ccdb][:password], node[:ccdb][:adapter] == "postgresql")
