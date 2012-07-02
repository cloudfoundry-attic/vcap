#
# Cookbook Name:: postgresql
# Recipe:: lifecycle
#
# Copyright 2012, VMware
#

service_lifecycle "postgresql_lifecycle" do
  service_type "postgresql"
end
