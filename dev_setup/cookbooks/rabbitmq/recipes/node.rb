#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2012, Uhuru Software
#

cloudfoundry_service "rabbit" do
  components ["rabbit_node"]
end
