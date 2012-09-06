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

bash "Setup warden server" do
  code <<-EOH
    cd #{node[:cloudfoundry][:path]}/warden/warden
    PATH="#{node[:ruby][:path]}/bin":${PATH}
    bundle install
    echo y | bundle exec rake setup[#{node[:deployment][:config_path]}/warden_server.conf]
  EOH
end

service "warden_server" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :restart ]
end
