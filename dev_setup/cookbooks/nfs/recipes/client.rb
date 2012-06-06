#
# Cookbook Name: nfs
# Recipe:: default
#
# Copyright 2011, VMware
#

case node['platform']
when "ubuntu"
  package "nfs-common"
else
  Chef::Log.error("Installation of NFS is not support on this platform.")
end
