#
# Cookbook Name:: stager
# Recipe:: default
#
# Copyright 2012, VMware
#

package "curl"

template node[:stager][:config_file] do
  path File.join(node[:deployment][:config_path], node[:stager][:config_file])
  source "stager.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

template "staging_redis.conf" do
  path File.join(node[:deployment][:config_path], "staging_redis.conf")
  source "staging_redis.conf.erb"
  owner node[:deployment][:user]
  mode 0644
end

template "staging_redis" do
  path File.join("", "etc", "init.d", "staging_redis")
  source "staging_redis.erb"
  owner node[:deployment][:user]
  mode 0755
end

service "staging_redis" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :restart ]
end

cf_bundle_install(File.expand_path("stager", node[:cloudfoundry][:home]))
