#
# Cookbook Name:: routerv2
# Recipe:: default
#
# Copyright 2011, VMware
#
template node[:routerv2][:config_file] do
  path File.join(node[:deployment][:config_path], node[:routerv2][:config_file])
  source "routerv2.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "routerv2")))
