#
# Cookbook Name:: service_broker
# Recipe:: default
#
# Copyright 2011, VMware
#

cloudfoundry_service "service_broker" do
  components ["service_broker"]
end
