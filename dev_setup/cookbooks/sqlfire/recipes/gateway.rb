#
# Cookbook Name:: gateway
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "sqlfire" do
  components ["sqlfire_gateway"]
end
