#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "echo" do
  components ["echo_node"]
end
