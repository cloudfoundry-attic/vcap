#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
#

include_recipe "mysql::default"

case node['platform']
when "ubuntu"
  bash "Setup mysql" do
    code <<-EOH
    echo mysql-server-5.1 mysql-server/root_password select #{node[:mysql][:server_root_password]} | debconf-set-selections
    echo mysql-server-5.1 mysql-server/root_password_again select #{node[:mysql][:server_root_password]} | debconf-set-selections
    EOH
    not_if do
      ::File.exists?("/usr/sbin/mysqld")
    end
  end

  package "mysql-server"

  template "/etc/mysql/my.cnf" do
    source "ubuntu.cnf.erb"
    owner "root"
    group "root"
    mode "0600"
  end
else
  Chef::Log.error("Installation of mysql not supported on this platform.")
end
