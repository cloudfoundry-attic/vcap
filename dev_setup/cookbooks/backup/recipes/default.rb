#
# Cookbook Name:: backup
# Recipe:: default
#
# Copyright 2011, VMware
#

# generate the service_backup_ctl
template "vcap_service_backup_ctl" do
  source "service_backup_ctl.erb"
  path File.join(node[:cloudfoundry][:home], "vcap", "dev_setup", "bin", "vcap_service_backup_ctl")
  mode "0755"
  owner node[:deployment][:user]
  group node[:deployment][:group]
end

# create directory to store backups
directory node[:backup][:dir] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
end
