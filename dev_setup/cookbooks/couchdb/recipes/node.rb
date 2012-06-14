#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "couchdb" do
  components ["couchdb_node"]
end
