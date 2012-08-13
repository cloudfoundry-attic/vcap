#
# Cookbook Name:: memcached
# Recipe:: default
#
# Copyright 2012, VMware
#

node[:memcached][:supported_versions].each do |version, install_version|
  #TODO, need more refine to actually support mutiple versions
  Chef::Log.info("Building memcached version: #{version} - #{install_version}")

  libevent_tarball_path = File.join(node[:deployment][:setup_cache], "libevent-#{node[:libevent][:version]}-stable.tar.gz")
  cf_remote_file libevent_tarball_path do
    owner node[:deployment][:user]
    id node[:libevent][:id]
    checksum node[:memcached][:checksums][:libevent]
  end

  memcached_tarball_path = File.join(node[:deployment][:setup_cache], "memcached-#{install_version}.tar.gz")
  cf_remote_file memcached_tarball_path do
    owner node[:deployment][:user]
    id node[:memcached][:id]
    checksum node[:memcached][:checksums][:memcached]
  end

  directory "#{node[:memcached][:path]}" do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
  end

  %w[bin etc var].each do |dir|
    directory File.join(node[:memcached][:path], dir) do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end
  end

  bash "Compile libevent" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
  tar xzf #{libevent_tarball_path}
  cd libevent-#{node[:libevent][:version]}-stable
  ./configure --prefix=`pwd`/tmp
  make
  make install
  EOH
  end

  bash "Install memcached" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
  tar xzf #{memcached_tarball_path}
  cd memcached-#{install_version}
  ./configure --with-libevent=../libevent-#{node[:libevent][:version]}-stable/tmp LDFLAGS="-static"
  make
  cp memcached #{File.join(node[:memcached][:path], "bin")}
  EOH
  end
end
