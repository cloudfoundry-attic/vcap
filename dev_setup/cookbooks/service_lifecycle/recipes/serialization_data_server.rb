#
# Cookbook Name:: service_lifecycle
# Recipe:: serialization_data_server
#
# Copyright 2012, VMware
#
template node[:serialization_data_server][:config_file] do
  path File.join(node[:deployment][:config_path], node[:serialization_data_server][:config_file])
  source "serialization_data_server.yml.erb"
  owner node[:deployment][:user]
  mode "0644"
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "services", "serialization_data_server")))
