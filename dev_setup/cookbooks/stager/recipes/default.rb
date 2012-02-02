#
# Cookbook Name:: stager
# Recipe:: default
#
# Copyright 2012, VMWARE
#
#

template node[:stager][:config_file] do
  path File.join(node[:deployment][:config_path], node[:stager][:config_file])
  source "stager.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "stager")))
