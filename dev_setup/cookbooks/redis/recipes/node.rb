#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "redis" do
  components ["redis_node", "redis_backup"]
end
