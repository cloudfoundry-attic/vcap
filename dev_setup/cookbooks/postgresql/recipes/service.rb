#
# Cookbook Name:: postgres service
# Recipe:: default
#
# Copyright 2011, VMware
#
#

cf_pg_update_hba_conf(node[:postgresql][:database], node[:postgresql][:server_root_user])
cf_pg_setup_db(node[:postgresql][:database], node[:postgresql][:server_root_user], node[:postgresql][:server_root_password])
