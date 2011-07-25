#
# Cookbook Name:: cloud_controller
# Recipe:: default
#
# Copyright 2011, VMware
#
#

template node[:cloud_controller][:config_file] do
  path File.join(node[:deployment][:cfg_path], node[:cloud_controller][:config_file])
  source "cloud_controller.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end
cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "cloud_controller")))

staging_dir = File.join(node[:deployment][:cfg_path], "staging")
node[:cloud_controller][:staging].each_pair do |framework, cfg|
  template cfg do
    path File.join(staging_dir, cfg)
    source "#{cfg}.erb"
    owner node[:deployment][:user]
    mode 0644
  end
end
