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

cf_remote_file File.join(node[:neo4j][:service_dir], "neo4j-server.tgz") do
  owner node[:deployment][:user]
  id node[:neo4j][:server_id]
  checksum node[:neo4j][:checksum][:server]
end

cf_remote_file File.join(node[:neo4j][:service_dir], "neo4j-hosting-extension.jar") do
  owner node[:deployment][:user]
  id node[:neo4j][:jar_id]
  checksum node[:neo4j][:checksum][:jar]
end
