#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"
  package "mysql-client"

  bash "Setup mysql" do
    code <<-EOH
    echo mysql-server-5.1 mysql-server/root_password select #{node[:mysql][:server_root_password]} | debconf-set-selections
    echo mysql-server-5.1 mysql-server/root_password_again select #{node[:mysql][:server_root_password]} | debconf-set-selections
    EOH
    not_if do
      ::File.exists?(File.join("", "usr", "sbin", "mysqld"))
    end
  end

  package "mysql-server"

  template File.join("", "etc", "mysql", "my.cnf") do
    source "ubuntu.cnf.erb"
    owner "root"
    group "root"
    mode "0600"
    notifies :restart, "service[mysql]"
  end

  service "mysql" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
  end
else
  Chef::Log.error("Installation of mysql not supported on this platform.")
end
