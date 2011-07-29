#
# Cookbook Name:: services
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:services].each do |service|
  ["#{service}_node.yml", "#{service}_gateway.yml", "#{service}_backup.yml"].each do |f|
    template f do
      path File.join(node[:deployment][:config_path], f)
      source "#{f}.erb"
      owner node[:deployment][:user]
      mode 0644
    end
  end

  cf_bundle_install(File.expand_path(File.join(node[:cloudfoundry][:path], "services", service)))
end
