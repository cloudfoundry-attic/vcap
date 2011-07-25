#
# Cookbook Name:: router
# Recipe:: default
#
# Copyright 2011, VMware
#
template node[:router][:config_file] do
  path File.join(node[:deployment][:config_path], node[:router][:config_file])
  source "router.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "router")))
