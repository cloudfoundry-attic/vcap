#
# Cookbook Name:: backup
# Recipe:: default
#
# Copyright 2011, VMware
#

directory node[:backup][:mount_point] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
end
# install nfs client
include_recipe "nfs::client"

# mount remote nfs direcotry
mount node[:backup][:mount_point] do
  mount_point node[:backup][:mount_point]
  device "#{node[:nfs][:server_local_ip]}:#{node[:nfs][:server_exports_dir]}"
  fstype "nfs"
  options "rw"
end

