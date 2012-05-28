#
# Cookbook Name:: ccdb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
cf_pg_reset_user_password(:ccdb)
cf_pg_update_hba_conf(node[:ccdb][:database], node[:ccdb][:user], node[:postgresql][:system_version])
cf_pg_setup_db(node[:ccdb][:database], node[:ccdb][:user], node[:ccdb][:password], node[:ccdb][:adapter] == "postgresql" && node[:postgresql][:system_version] == node[:postgresql][:service_version] && node[:postgresql][:system_port] == node[:postgresql][:service_port], node[:postgresql][:system_port])
