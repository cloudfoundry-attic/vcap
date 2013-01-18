#
# Cookbook Name:: service_redis
# Recipe:: default
#
# Copyright 2012, VMware
#

directory "#{node[:service_redis][:path]}" do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

directory File.join(node[:service_redis][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  action :create
end

tarball_path = File.join(node[:deployment][:setup_cache], "redis-2.2.15.tar.gz")
cf_remote_file tarball_path do
  owner node[:deployment][:user]
  id node[:service_redis][:id]
  checksum node[:service_redis][:checksum]
end

bash "Install service_redis" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    tar xzf "#{tarball_path}"
    cd redis-2.2.15
    make
    install src/redis-server #{File.join(node[:service_redis][:path], "bin")}
  EOH
end

directory "#{node[:service_redis][:persistence_dir]}" do
  owner node[:deployment][:user]
  group node[:deployment][:user]
  mode "0755"
end

template File.join(node[:deployment][:config_path], "services_redis.conf") do
  source "services_redis.conf.erb"
  mode 0644
  owner node[:deployment][:user]
  group node[:deployment][:group]
end
