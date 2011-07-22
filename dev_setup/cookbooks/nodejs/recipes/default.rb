#
# Cookbook Name:: nodejs
# Recipe:: default
#
# Copyright 2011, VMware
#
# All rights reserved - Do Not Redistribute
#
%w[ build-essential ].each do |pkg|
  package pkg
end

remote_file "/tmp/node-v#{node[:nodejs][:version]}.tar.gz" do
  owner node[:nodejs][:user]
  source node[:nodejs][:source]
  not_if { ::File.exists?("/tmp/node-v#{node[:nodejs][:version]}.tar.gz") }
end

directory node[:nodejs][:path] do
  owner node[:nodejs][:user]
  group node[:nodejs][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Nodejs" do
  cwd "/tmp"
  user node[:nodejs][:user]
  code <<-EOH
  tar xzf node-v#{node[:nodejs][:version]}.tar.gz
  cd node-v#{node[:nodejs][:version]}
  ./configure --prefix=#{node[:nodejs][:path]}
  make
  make install
  EOH
  not_if do
    ::File.exists?("#{node[:nodejs][:path]}/bin/node")
  end
end
