#
# Cookbook Name:: snapshot
# Recipe:: default
#
# Copyright 2012, VMware
#

# create directory to store snapshots
directory node[:snapshot][:dir] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
end

# create tmp direcotry
if node[:service_lifecycle][:tmp_dir] != "/tmp"
  directory node[:service_lifecycle][:tmp_dir] do
    mode "0755"
    recursive true
  end
end
