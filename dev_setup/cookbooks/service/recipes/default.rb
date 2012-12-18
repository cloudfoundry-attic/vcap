#
# Cookbook Name:: service_common
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"
  directory node[:service][:path] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  directory node[:service][:common_path] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    action :create
  end

  template File.join(node[:service][:common_path], "utils.sh") do
    source "utils.erb"
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
  end
else
  Chef::Log.error("Installation of echo server not supported on this platform.")
end
