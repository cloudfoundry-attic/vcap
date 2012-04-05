#
# Cookbook Name:: uaadb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
cf_pg_update_hba_conf(node[:uaadb][:database], node[:uaadb][:user])
cf_pg_setup_db(node[:uaadb][:database], node[:uaadb][:user], node[:uaadb][:password])
