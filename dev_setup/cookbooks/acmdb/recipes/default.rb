#
# Cookbook Name:: acmdb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
cf_pg_reset_user_password(:acmdb)
cf_pg_update_hba_conf(node[:acmdb][:database], node[:acmdb][:user], node[:postgresql][:system_version])
cf_pg_setup_db(node[:acmdb][:database], node[:acmdb][:user], node[:acmdb][:password], node[:acmdb][:adapter] == "postgresql" && node[:postgresql][:system_version] == node[:postgresql][:service_version] && node[:postgresql][:system_port] == node[:postgresql][:service_port], node[:postgresql][:system_port])
