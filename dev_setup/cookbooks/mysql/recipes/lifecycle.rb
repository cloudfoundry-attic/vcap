#
# Cookbook Name:: mysql
# Recipe:: lifecycle
#
# Copyright 2012, VMware
#

service_lifecycle "mysql_lifecycle" do
  service_type "mysql"
end
