#
# Cookbook Name:: gateway
# Recipe:: default
#
# Copyright 2012, Uhuru Software
#

cloudfoundry_service "rabbit" do
  components ["rabbit_gateway"]
end
