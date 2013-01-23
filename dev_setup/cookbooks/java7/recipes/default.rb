#
# Cookbook Name:: java7
# Recipe:: default
#
# Copyright 2012, VMware
#
#

case node['platform']
when "ubuntu"
  machine =  node[:kernel][:machine]
  pkg_path = File.join(node[:deployment][:setup_cache], "jre-7u4-linux-#{machine}.tar.gz")
  cf_remote_file pkg_path do
    owner node[:deployment][:user]
    id node[:java7][:id]["#{machine}"]
    checksum node[:java7][:checksum]["#{machine}"]
  end

  directory node[:java7][:java_home] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  bash "Install java7" do
    cwd node[:java7][:java_home]
    user node[:deployment][:user]
    code <<-EOH
      tar zxf #{pkg_path}
    EOH
  end
else
  Chef::Log.error("Java 7 not supported on this platform.")
end
