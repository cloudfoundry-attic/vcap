#
# Cookbook Name:: redis
# Recipe:: default
#
# Copyright 2012, VMware
#

directory node[:redis][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install redis tools" do
  user node[:deployment][:user]
  code <<-EOH
    mkdir -p #{node[:redis][:path]}/common/bin
    cp #{node[:service][:common_path]}/utils.sh #{node[:redis][:path]}/common/bin
  EOH
end

template File.join(node[:redis][:path], "common", "bin", "warden_service_ctl") do
   source "warden_service_ctl.erb"
   mode 0755
end

node[:redis][:supported_versions].each do |version, install_version|
  Chef::Log.info("Building redis version: #{version} - #{install_version}")

  source_file_id, source_file_checksum = id_and_checksum_for_redis_version(install_version)

  cf_remote_file File.join(node[:deployment][:setup_cache], "redis-#{install_version}.tar.gz") do
    owner node[:deployment][:user]
    id source_file_id
    checksum source_file_checksum
  end

  install_dir = File.join(node[:redis][:path], "#{version}", "bin")
  bash "Install Redis #{version} (#{install_version})" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
    tar xzf #{File.join(node[:deployment][:setup_cache], "redis-#{install_version}.tar.gz")}
    cd redis-#{install_version}
    make
    mkdir -p #{install_dir}
    install src/redis-server #{install_dir}
    EOH
  end
end

# deploy redis local
local_redis = File.join(node[:deployment][:home], "deploy", "redis")
directory local_redis do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
end

%w[bin etc var].each do |dir|
  directory File.join(local_redis, dir) do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

bash "Install Redis in local" do
  user node[:deployment][:user]
  code <<-EOH
    cd /tmp/redis-2.2.15/src
    install redis-benchmark redis-cli redis-server redis-check-dump redis-check-aof #{File.join(local_redis, "bin")}
  EOH
end
