#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "neo4j" do
  components ["neo4j_node"]
end
