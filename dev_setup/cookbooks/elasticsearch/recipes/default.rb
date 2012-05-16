#
# Cookbook Name:: elasticsearch
# Recipe:: default
#
# Copyright 2011, VMware
#
[node[:elasticsearch][:service_dir], File.join(node[:elasticsearch][:service_dir], "instances")].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:user]
    mode "0755"
  end
end

remote_file File.join(node[:elasticsearch][:service_dir], "elasticsearch-server.tgz") do
  owner node[:deployment][:user]
  source "https://github.com/downloads/elasticsearch/elasticsearch/#{node[:elasticsearch][:distribution_file]}"
  not_if { ::File.exists?(File.join(node[:elasticsearch][:service_dir], "elasticsearch-server.tgz")) }
end

remote_file File.join(node[:elasticsearch][:service_dir], "elasticsearch-http-basic.jar") do
  owner node[:deployment][:user]
  source "https://github.com/downloads/Asquera/elasticsearch-http-basic/#{node[:elasticsearch][:http_auth_plugin]}"
  not_if { ::File.exists?(File.join(node[:elasticsearch][:service_dir], "elasticsearch-http-basic.jar")) }
end
