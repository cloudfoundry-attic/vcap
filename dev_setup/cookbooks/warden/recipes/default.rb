#
# Cookbook Name:: warden
# Recipe:: default
#
# Copyright 2012, VMware
#

%w[ build-essential debootstrap libnl1 quota ].each do |pkg|
  package pkg
end

template "warden_server.conf" do
  path File.join(node[:deployment][:config_path], "warden_server.conf")
  source "warden_server.conf.erb"
  owner node[:deployment][:user]
  mode 0644
end

template "warden_server" do
  path File.join("", "etc", "init.d", "warden_server")
  source "warden_server.erb"
  mode 0700
end

bash "bundle install" do
  user node[:deployment][:user]
  code <<-EOH
    cd #{node[:cloudfoundry][:path]}/warden/warden
    PATH="#{node[:ruby][:path]}/bin":${PATH}
    bundle install
  EOH
end

bash "Setup warden server" do
  code <<-EOH
    cd #{node[:cloudfoundry][:path]}/warden/warden
    PATH="#{node[:ruby][:path]}/bin":${PATH}
    echo y | bundle exec rake setup[#{node[:deployment][:config_path]}/warden_server.conf]
  EOH
end

cf_remote_file File.join(node[:warden][:rootfs_path], "lib", "libaio.so.1") do
  id node[:warden][:id][:libaio]
  checksum node[:warden][:checksum][:libaio]
end
