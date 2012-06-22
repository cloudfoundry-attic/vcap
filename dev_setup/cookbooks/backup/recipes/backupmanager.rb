#
# Cookbook Name:: backup
# Recipe:: backup_manager
#
# Copyright 2011, VMware
#
template node[:backup_manager][:config_file] do
  path File.join(node[:deployment][:config_path], node[:backup_manager][:config_file])
  source "backup_manager.yml.erb"
  owner node[:deployment][:user]
  mode "0644"
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "services", "tools", "backup", "manager")))
