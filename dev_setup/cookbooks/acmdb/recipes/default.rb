#
# Cookbook Name:: acmdb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
cf_pg_update_hba_conf(node[:acmdb][:database], node[:acmdb][:user])
cf_pg_setup_db(node[:acmdb][:database], node[:acmdb][:user], node[:acmdb][:password])
