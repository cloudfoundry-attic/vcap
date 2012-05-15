#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "postgresql" do
  components ["postgresql_node"]
end
