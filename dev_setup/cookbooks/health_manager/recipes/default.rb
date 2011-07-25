#
# Cookbook Name:: health_manager
# Recipe:: default
#
# Copyright 2011, VMware
#
template node[:health_manager][:config_file] do
  path File.join(node[:deployment][:config_path], node[:health_manager][:config_file])
  source "health_manager.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "health_manager")))
