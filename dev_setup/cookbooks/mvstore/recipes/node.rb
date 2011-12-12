#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "mvstore" do
  components ["mvstore_node"]
end
