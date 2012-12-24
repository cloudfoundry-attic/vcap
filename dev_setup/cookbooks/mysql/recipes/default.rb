#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
#

version = "5.5.27-rel28.1-296.Linux.x86_64"

client_package = File.join(node[:deployment][:setup_cache], "client-#{version}.tar.gz")
cf_remote_file client_package do
  owner node[:deployment][:user]
  id node[:mysql][:id][:client]
  checksum node[:mysql][:checksum][:client]
end

server_package = File.join(node[:deployment][:setup_cache], "server-#{version}.tar.gz")
cf_remote_file server_package do
  owner node[:deployment][:user]
  id node[:mysql][:id][:server]
  checksum node[:mysql][:checksum][:server]
end

initdb_package = File.join(node[:deployment][:setup_cache], "mysql-initdb-#{version}.tar.gz")
cf_remote_file initdb_package do
  owner node[:deployment][:user]
  id node[:mysql][:id][:initdb]
  checksum node[:mysql][:checksum][:initdb]
end

directory node[:mysql][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install mysql client" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    mkdir -p "#{node[:mysql][:path]}/mysqlclient"
    tar zxvf #{client_package}
    cd client-#{version}
    for x in bin include lib; do
      cp -a ${x} "#{node[:mysql][:path]}/mysqlclient"
    done
  EOH
  not_if do
    ::File.exists?(File.join("#{node[:mysql][:path]}", "mysqlclient", "bin", "mysql"))
  end
end

bash "install mysql server" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    mkdir -p "#{node[:mysql][:path]}/#{node[:mysql][:default_version]}"
    tar zxvf #{server_package}
    cd server-#{version}
    for x in bin include lib libexec share; do
      cp -a ${x} "#{node[:mysql][:path]}/#{node[:mysql][:default_version]}"
    done
  EOH
  not_if do
    ::File.exists?(File.join("#{node[:mysql][:path]}", "#{node[:mysql][:default_version]}", "bin", "mysql"))
  end
end

bash "install initdb" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    tar zxvf #{initdb_package}
    cp -a initdb55 "#{node[:mysql][:path]}/#{node[:mysql][:default_version]}"
  EOH
  not_if do
    ::File.exists?(File.join("#{node[:mysql][:path]}", "#{node[:mysql][:default_version]}", "initdb55"))
  end
end

template File.join(node[:mysql][:path], node[:mysql][:default_version], "libexec", "mysql_warden.server") do
   source "mysql55_warden.server.erb"
   owner node[:deployment][:user]
   mode 0755
end

directory File.join(node[:mysql][:path], "common", "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

directory File.join(node[:mysql][:path], "common", "config") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install mysql tools" do
  user node[:deployment][:user]
  code <<-EOH
    cp #{node[:service][:common_path]}/utils.sh #{node[:mysql][:path]}/common/bin
  EOH
end

template File.join(node[:mysql][:path], "common", "bin", "warden_service_ctl") do
   source "warden_service_ctl.erb"
   owner node[:deployment][:user]
   mode 0755
end

template File.join(node[:mysql][:path], "common", "config", "warden_mysql_init") do
   source "warden_mysql_init.erb"
   owner node[:deployment][:user]
   mode 0644
end

template File.join(node[:mysql][:path], "common", "config", "my55.cnf") do
   source "my55.cnf.erb"
   owner node[:deployment][:user]
   mode 0644
end
