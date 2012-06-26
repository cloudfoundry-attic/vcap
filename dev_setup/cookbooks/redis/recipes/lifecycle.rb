#
# Cookbook Name:: redis
# Recipe:: lifecycle
#
# Copyright 2012, VMware
#

service_lifecycle "redis_lifecycle" do
  service_type "redis"
end
