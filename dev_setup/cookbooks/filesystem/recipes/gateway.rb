#
# Cookbook Name:: gateway
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "filesystem" do
  components ["filesystem_gateway"]
end
