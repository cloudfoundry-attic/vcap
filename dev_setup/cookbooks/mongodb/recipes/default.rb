#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:mongodb][:supported_versions].each do |version, install_version|
  Chef::Log.info("Building Mongo Version: #{version} - #{install_version}")

  install_path = File.join(node[:warden][:rootfs_path], "usr", "share", "mongodb", "mongodb-#{version}")
  source_file_id, source_file_checksum = id_and_checksum_for_version(install_version)

  mongodb_tarball_path = File.join(node[:deployment][:setup_cache], "mongodb-linux-#{node[:kernel][:machine]}-#{install_version}.tgz")

  cf_remote_file mongodb_tarball_path do
    owner node[:deployment][:user]
    id source_file_id
    checksum source_file_checksum
  end

  directory File.join(install_path) do
    mode "0755"
    recursive true
    action :create
  end

  bash "Install Mongodb #{version} (#{install_version})" do
    cwd File.join("", "tmp")
    code <<-EOH
    tar xvzf #{mongodb_tarball_path}
    cd mongodb-linux-#{node[:kernel][:machine]}-#{install_version}
    cp #{File.join("bin", "*")} #{File.join(install_path)}
    EOH
    not_if do
      ::File.exists?(File.join(install_path, "mongo"))
    end
  end
end

template "mongod_startup.sh" do
   path File.join(node[:warden][:rootfs_path], "usr", "bin", "mongod_startup.sh")
   source "mongod_startup.sh.erb"
   mode 0755
end

template "mongodb.conf" do
   path File.join(node[:warden][:rootfs_path], "etc", "mongodb.conf")
   source "mongodb.conf.erb"
   mode 0644
end
