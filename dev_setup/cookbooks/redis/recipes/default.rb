#
# Cookbook Name:: redis
# Recipe:: default
#
# Copyright 2012, VMware
#

node[:redis][:supported_versions].each do |version, install_version|
  #TODO, need more refine to actually support mutiple versions
  Chef::Log.info("Building redis version: #{version} - #{install_version}")

  cf_remote_file File.join(node[:deployment][:setup_cache], "redis-#{install_version}.tar.gz") do
    owner node[:deployment][:user]
    id node[:redis][:id]
    checksum node[:redis][:checksum]
  end

  directory "#{node[:redis][:path]}" do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
  end

  %w[bin etc var].each do |dir|
    directory File.join(node[:redis][:path], dir) do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end
  end

  bash "Install Redis" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
  tar xzf #{File.join(node[:deployment][:setup_cache], "redis-#{install_version}.tar.gz")}
  cd redis-#{install_version}
  make
  cd src
  install redis-benchmark redis-cli redis-server redis-check-dump redis-check-aof #{File.join(node[:redis][:path], "bin")}
  EOH
  end

  template File.join(node[:redis][:path], "etc", "redis.conf") do
    source "redis.conf.erb"
    mode 0600
    owner node[:deployment][:user]
    group node[:deployment][:group]
  end
end
