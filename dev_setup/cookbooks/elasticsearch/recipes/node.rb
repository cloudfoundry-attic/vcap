#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "elasticsearch" do
  components ["elasticsearch_node"]
end
