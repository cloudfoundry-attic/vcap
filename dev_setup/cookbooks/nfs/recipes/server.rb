#
# Cookbook Name: nfs
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:nfs][:server_local_ip] ||= node[:nfs][:host]
node[:nfs][:server_local_subnet] ||= node[:deployment][:local_subnet]

case node['platform']
when "ubuntu"
  package "nfs-kernel-server"

  # configure the server
  directory node[:nfs][:server_exports_dir] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  template "exports" do
    path "/etc/exports"
    source "exports.conf.erb"
    owner node[:deployment][:user]
    mode "0644"
  end

  template "idmapd.conf" do
    path "/etc/idmapd.conf"
    source "idmapd.conf.erb"
    owner node[:deployment][:user]
    mode "0644"
  end

  service "nfs-kernel-server" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

else
  Chef::Log.error("Installation of NFS is not support on this platform.")
end

