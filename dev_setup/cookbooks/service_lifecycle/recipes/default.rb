#
# Cookbook Name:: snapshot
# Recipe:: default
#
# Copyright 2011, VMware
#

# generate the service_snapshot_ctl
#template "vcap_service_snapshot_ctl" do
#  source "service_snapshot_ctl.erb"
#  path File.join(node[:cloudfoundry][:home], "vcap", "dev_setup", "bin", "vcap_service_snapshot_ctl")
#  mode "0755"
#  owner node[:deployment][:user]
#  group node[:deployment][:group]
#end

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
