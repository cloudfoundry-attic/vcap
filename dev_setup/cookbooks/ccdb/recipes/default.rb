#
# Cookbook Name:: ccdb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
cf_pg_update_hba_conf(node[:ccdb][:database], node[:ccdb][:user])
cf_pg_setup_db(node[:ccdb][:database], node[:ccdb][:user], node[:ccdb][:password])
