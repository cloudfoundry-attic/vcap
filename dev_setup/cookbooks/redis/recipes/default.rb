#
# Cookbook Name:: redis
# Recipe:: default
#
# Copyright 2012, VMware
#

# deploy redis in warden
template "redis_startup.sh" do
   path File.join(node[:warden][:rootfs_path], "usr", "bin", "redis_startup.sh")
   source "redis_startup.sh.erb"
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

  install_dir = File.join(node[:warden][:rootfs_path], node[:redis][:path_in_warden], "redis-#{version}", "bin")
  bash "Install Redis #{version} (#{install_version})" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
    tar xzf #{File.join(node[:deployment][:setup_cache], "redis-#{install_version}.tar.gz")}
    cd redis-#{install_version}
    make
    sudo mkdir -p #{install_dir}
    sudo install src/redis-server #{install_dir}
    EOH
  end
end

# deploy redis local
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

bash "Install Redis in local" do
  user node[:deployment][:user]
  code <<-EOH
    cd /tmp/redis-2.2.15/src
    install redis-benchmark redis-cli redis-server redis-check-dump redis-check-aof #{File.join(node[:redis][:path], "bin")}
  EOH
end
