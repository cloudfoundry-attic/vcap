#
# Cookbook Name:: vcap_redis
# Recipe:: default
#
# Copyright 2012, VMware
#

directory "#{node[:vcap_redis][:path]}" do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
end

%w[bin etc var].each do |dir|
  directory File.join(node[:vcap_redis][:path], dir) do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

tarball_path = File.join(node[:deployment][:setup_cache], "redis-2.2.15.tar.gz")
cf_remote_file tarball_path do
  owner node[:deployment][:user]
  id node[:vcap_redis][:id]
  checksum node[:vcap_redis][:checksum]
end

bash "Install vcap_redis" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    tar xzf "#{tarball_path}"
    cd redis-2.2.15
    make
    install src/redis-server #{File.join(node[:vcap_redis][:path], "bin")}
  EOH
end

template "vcap_redis.conf" do
  path File.join(node[:deployment][:config_path], "vcap_redis.conf")
  source "vcap_redis.conf.erb"
  owner node[:deployment][:user]
  mode 0644
end

template "vcap_redis" do
  path File.join("", "etc", "init.d", "vcap_redis")
  source "vcap_redis.erb"
  owner node[:deployment][:user]
  mode 0755
end

service "vcap_redis" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :restart ]
end
