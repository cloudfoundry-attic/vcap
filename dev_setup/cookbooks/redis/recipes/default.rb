#
# Cookbook Name:: redis
# Recipe:: default
#
# Copyright 2012, VMware
#

node[:redis][:supported_versions].each do |version, install_version|
  Chef::Log.info("Building redis version: #{version} - #{install_version}")

  install_path = File.join(node[:deployment][:home], "deploy", "redis", install_version)
  source_file_id, source_file_checksum = id_and_checksum_for_redis_version(install_version)

  cf_remote_file File.join(node[:deployment][:setup_cache], "redis-#{install_version}.tar.gz") do
    owner node[:deployment][:user]
    id source_file_id
    checksum source_file_checksum
  end

  directory install_path do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  %w[bin etc var].each do |dir|
    directory File.join(install_path, dir) do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end
  end

  bash "Install Redis #{version} (#{install_version})" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
  tar xzf #{File.join(node[:deployment][:setup_cache], "redis-#{install_version}.tar.gz")}
  cd redis-#{install_version}
  make
  cd src
  install redis-benchmark redis-cli redis-server redis-check-dump redis-check-aof #{File.join(install_path, "bin")}
  EOH
  end

  template File.join(install_path, "etc", "redis.conf") do
    source "redis.conf.erb"
    mode 0600
    owner node[:deployment][:user]
    group node[:deployment][:group]
  end
end
