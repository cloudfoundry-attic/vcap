#
# Cookbook Name:: postgres service
# Recipe:: default
#
# Copyright 2011, VMware
#
#

version = node[:postgresql][:default_version]

postgresql_package = File.join(node[:deployment][:setup_cache], "postgresql-#{version}-x86_64.tar.gz")
cf_remote_file postgresql_package do
  owner node[:deployment][:user]
  id node[:postgresql_node][:id][:package]["#{version}"]
  checksum node[:postgresql_node][:checksum][:package]["#{version}"]
end

postgresql_initdb = File.join(node[:deployment][:setup_cache], "postgresql-initdb-#{version}-x86_64.tar.gz")
cf_remote_file postgresql_initdb do
  owner node[:deployment][:user]
  id node[:postgresql_node][:id][:initdb]["#{version}"]
  checksum node[:postgresql_node][:checksum][:initdb]["#{version}"]
end

directory node[:postgresql_node][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install postgresql #{version}" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    mkdir "postgresql-#{version}-x86_64"
    mkdir -p "#{node[:postgresql_node][:path]}/#{version}"
    cd "postgresql-#{version}-x86_64"
    tar zxvf #{postgresql_package}
    cp -a * "#{node[:postgresql_node][:path]}/#{version}"
  EOH
  not_if do
    ::File.exists?(File.join("#{node[:postgresql_node][:path]}", "#{version}", "bin", "postgres"))
  end
end

initdb_dir = File.join(node[:postgresql_node][:path], node[:postgresql][:default_version], "initdb")
directory initdb_dir do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install initdb" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    tar zxvf #{postgresql_initdb}
    cp -r initdb/* #{initdb_dir}
    mkdir -p #{initdb_dir}/pg_log
    chmod -R 755 "#{initdb_dir}"
  EOH
  not_if do
    ::File.exists?(File.join("#{node[:postgresql_node][:path]}", "#{node[:postgresql][:default_version]}", "initdb"))
  end
end

template File.join(initdb_dir, "postgresql.conf") do
   source "postgresql91.conf.erb"
   owner node[:deployment][:user]
   mode 0755
end

directory File.join(node[:postgresql_node][:path], "common", "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

directory File.join(node[:postgresql_node][:path], "common", "config") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install postgresql tools" do
  user node[:deployment][:user]
  code <<-EOH
    cp #{node[:service][:common_path]}/utils.sh #{node[:postgresql_node][:path]}/common/bin
  EOH
end

template File.join(node[:postgresql_node][:path], "common", "bin", "warden_service_ctl") do
   source "warden_service_ctl.erb"
   owner node[:deployment][:user]
   mode 0755
end

template File.join(node[:postgresql_node][:path], "common", "bin", "pre_service_start.sh") do
   source "pre_service_start.sh.erb"
   owner node[:deployment][:user]
   mode 0755
end

template File.join(node[:postgresql_node][:path], "common", "bin", "post_service_start.sh") do
   source "post_service_start.sh.erb"
   owner node[:deployment][:user]
   mode 0755
end

template File.join(node[:postgresql_node][:path], "common", "bin", "postgresql_ctl") do
   source "postgresql_ctl.erb"
   owner node[:deployment][:user]
   mode 0755
end
