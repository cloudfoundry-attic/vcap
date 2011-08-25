#
# Cookbook Name:: gateway
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "mongodb" do
  components ["mongodb_gateway"]
end
