#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "mysql" do
  components ["mysql_node", "mysql_backup"]
end
