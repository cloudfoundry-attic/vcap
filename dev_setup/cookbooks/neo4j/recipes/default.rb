#
# Cookbook Name:: neo4j
# Recipe:: default
#
# Copyright 2011, VMware
#
[node[:neo4j][:service_dir], File.join(node[:neo4j][:service_dir], "instances")].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:user]
    mode "0755"
  end
end

remote_file File.join(node[:neo4j][:service_dir], "neo4j-server.tgz") do
  owner node[:deployment][:user]
  source "http://dist.neo4j.org/#{node[:neo4j][:distribution_file]}"
  not_if { ::File.exists?(File.join(node[:neo4j][:service_dir], "neo4j-server.tgz")) }
end

remote_file File.join(node[:neo4j][:service_dir], "neo4j-hosting-extension.jar") do
  owner node[:deployment][:user]
  source "http://dist.neo4j.org/#{node[:neo4j][:hosting_extension]}"
  not_if { ::File.exists?(File.join(node[:neo4j][:service_dir], "neo4j-hosting-extension.jar")) }
end
