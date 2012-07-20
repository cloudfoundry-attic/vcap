#
# Cookbook Name:: staging_manifest
# Recipe:: default
#
# Copyright 2012, VMware
#
#

staging_dir = File.join(node[:deployment][:config_path], "staging")

node[:staging_manifest].each_pair do |framework, config|
  template config do
    path File.join(staging_dir, config)
    source "#{config}.erb"
    owner node[:deployment][:user]
    mode 0644
  end
end
