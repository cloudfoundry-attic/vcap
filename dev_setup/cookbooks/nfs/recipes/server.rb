#
# Cookbook Name: nfs
# Recipe:: default
#
# Copyright 2011, VMware
#

case node['platform']
when "ubuntu"
  package "nfs-kernel-server"

  # configure the server
  directory node[:nfs_server][:exports_dir] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  template "exports" do
    path File.join(node[:deployment][:config_path],"nfs_exports")
    source "exports.conf.erb"
    owner node[:deployment][:user]
    mode "0644"
  end

  bash "write_or_append_to_exports" do
    user "root"
    code <<-EOH
      if test -e /etc/exports
      then
        cat /etc/exports | grep -v #{node[:nfs_server][:exports_dir]} >/tmp/exports
        (cat /tmp/exports; cat #{File.join(node[:deployment][:config_path], "nfs_exports")}) > /etc/exports
      else
        cp -rf #{File.join(node[:deployment][:config_path],"nfs_exports")} /etc/exports
      fi
    EOH
  end

  template "idmapd.conf" do
    path "/etc/idmapd.conf"
    source "idmapd.conf.erb"
    owner node[:deployment][:user]
    mode "0644"
  end

  # reload nfs-server
  service "nfs-kernel-server" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :reload ]
  end

else
  Chef::Log.error("Installation of NFS is not support on this platform.")
end

