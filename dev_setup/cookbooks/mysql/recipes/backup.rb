#
# Cookbook Name:: mysql
# Recipe:: backup
#
# Copyright 2011, VMware
#

service_backup "mysql_backup" do
  service_type "mysql"
end
