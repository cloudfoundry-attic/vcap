#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"
  package "nginx"
  template "nginx.conf" do
    path "#{node[:nginx][:dir]}/nginx.conf"
    source "ubuntu-nginx.conf.erb"
    owner "root"
    group "root"
    mode 0644
  end

  service "nginx" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
  end
else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
