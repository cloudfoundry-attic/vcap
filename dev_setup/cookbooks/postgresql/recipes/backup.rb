#
# Cookbook Name:: postgresql
# Recipe:: backup
#
# Copyright 2011, VMware
#

service_backup "postgresql_backup" do
  service_type "postgresql"
end
