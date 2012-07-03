#
# Cookbook Name:: mongodb
# Recipe:: backup
#
# Copyright 2011, VMware
#

service_backup "mongodb_backup" do
  service_type "mongodb"
end
