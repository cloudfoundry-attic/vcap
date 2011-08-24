#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "mongodb" do
  components ["mongodb_node", "mongodb_backup"]
end
