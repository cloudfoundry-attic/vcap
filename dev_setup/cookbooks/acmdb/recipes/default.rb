#
# Cookbook Name:: acmdb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
unless node[:acmdb][:adapter] != "postgresql"
  # override the postgresql's user and password
  node[:acmdb][:user] = node[:postgresql][:server_root_user]
  node[:acmdb][:password] = node[:postgresql][:server_root_password]
end
cf_pg_update_hba_conf(node[:acmdb][:database], node[:acmdb][:user])
cf_pg_setup_db(node[:acmdb][:database], node[:acmdb][:user], node[:acmdb][:password], node[:acmdb][:adapter] == "postgresql")
