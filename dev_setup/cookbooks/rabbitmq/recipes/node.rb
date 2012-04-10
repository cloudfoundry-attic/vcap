#
# Cookbook Name:: node
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "rabbitmq" do
  components ["rabbitmq_node"]
end
