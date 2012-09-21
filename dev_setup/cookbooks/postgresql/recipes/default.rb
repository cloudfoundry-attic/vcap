#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#

if node[:postgresql][:system_version] != node[:postgresql][:service_version] && node[:postgresql][:system_port] == node[:postgresql][:service_port]
  Chef::Log.error("Different versions of postgresql will be installed, but they should listen different ports")
  exit 1
else
  if node[:postgresql][:system_version] == node[:postgresql][:service_version] && node[:postgresql][:system_port] != node[:postgresql][:service_port]
    Chef::Log.error("Fail to listen on differnt ports using the same  postgresql for diffrent components")
    exit 1
  end
end

case node['platform']
when "ubuntu"

  machine =  node[:kernel][:machine]
  libpq_deb_path = File.join(node[:deployment][:setup_cache], "libpq5_9.2.deb")
  cf_remote_file libpq_deb_path do
    owner node[:deployment][:user]
    id node[:postgresql][:id][:libpq]["#{machine}"]
    checksum node[:postgresql][:checksum][:libpq]["#{machine}"]
  end

  libpq_dev_deb_path = File.join(node[:deployment][:setup_cache], "libpq-dev_9.2.deb")
  cf_remote_file libpq_dev_deb_path do
    owner node[:deployment][:user]
    id node[:postgresql][:id][:libpq_dev]["#{machine}"]
    checksum node[:postgresql][:checksum][:libpq_dev]["#{machine}"]
  end

  bash "Install libpq" do
    code <<-EOH
    dpkg -i #{libpq_deb_path}
    EOH
  end

  bash "Install libpq-dev" do
    code <<-EOH
    dpkg -i #{libpq_dev_deb_path}
    EOH
  end

  %w[libc6 libcomerr2 libgssapi-krb5-2 libkrb5-3 libldap-2.4-2 libpam0g libssl0.9.8 libxml2 tzdata ssl-cert locales libedit2 zlib1g].each do |pkg|
    package pkg
  end

  client_common_path = File.join(node[:deployment][:setup_cache], "postgresql-client-common_130.deb")
  cf_remote_file client_common_path do
    owner node[:deployment][:user]
    id node[:postgresql][:id][:client_common]
    checksum node[:postgresql][:checksum][:client_common]
  end

  server_common_path = File.join(node[:deployment][:setup_cache], "postgresql-common_130.deb")
  cf_remote_file server_common_path do
    owner node[:deployment][:user]
    id node[:postgresql][:id][:server_common]
    checksum node[:postgresql][:checksum][:server_common]
  end

  bash "Install postgresql client common" do
    code <<-EOH
    dpkg -i #{client_common_path}
    EOH
  end

  bash "Install postgresql common" do
    code <<-EOH
    dpkg -i #{server_common_path}
    EOH
  end

else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end
