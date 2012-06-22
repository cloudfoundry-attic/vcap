#
# Cookbook Name:: redis
# Recipe:: backup
#
# Copyright 2011, VMware
#

service_backup "redis_backup" do
  service_type "redis"
  end
