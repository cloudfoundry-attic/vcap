#
# Cookbook Name:: service_lifecycle
# Recipe:: snapshot_manager
#
# Copyright 2012, VMware
#
template node[:snapshot_manager][:config_file] do
  path File.join(node[:deployment][:config_path], node[:snapshot_manager][:config_file])
  source "snapshot_manager.yml.erb"
  owner node[:deployment][:user]
  mode "0644"
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "services", "tools", "backup", "manager")))
