#
# Cookbook Name: nfs
# Recipe:: default
#
# Copyright 2011, VMware
#

case node['platform']
when "ubuntu"
  node[:nfs][:packages].each do |pkg|
    package pkg
  end
else
  Chef::Log.error("Installation of NFS is not support on this platform.")
end

