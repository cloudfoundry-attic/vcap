#
# Cookbook Name:: nats
# Recipe:: default
#
# Copyright 2011, VMware
#

gem_package "nats" do
  gem_binary "#{node[:ruby][:path]}/bin/gem"
end

nats_config_dir = File.join(node[:deployment][:config_path], "nats-server")
node[:nats][:config] = File.join(nats_config_dir, "nats-server.yml")

directory nats_config_dir do
  owner node[:deployment][:user]
  mode "0755"
  recursive true
  action :create
  notifies :restart, "service[nats-server]"
end

template "nats.yml" do
  path node[:nats][:config]
  source "nats-server.yml.erb"
  owner node[:deployment][:user]
  mode 0644
  notifies :restart, "service[nats-server]"
end

case node['platform']
when "ubuntu"
  template "nats-server" do
    path "/etc/init.d/nats-server"
    source "nats-server.erb"
    owner node[:deployment][:user]
    mode 0755
    notifies :restart, "service[nats-server]"
  end

  service "nats-server" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
  end
else
  Chef::Log.error("Installation of nats-server not supported on this platform.")
end
