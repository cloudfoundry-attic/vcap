#
# Cookbook Name:: gateway
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "postgresql" do
  components ["postgresql_gateway"]
end
