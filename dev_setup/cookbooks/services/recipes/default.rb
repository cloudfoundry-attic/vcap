#
# Cookbook Name:: services
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:services].each do |svc|
  ["#{svc}_node.yml", "#{svc}_gateway.yml", "#{svc}_backup.yml"].each do |f|
    template f do
      path File.join(node[:deployment][:cfg_path], f)
      source "#{f}.erb"
      owner node[:deployment][:user]
      mode 0644
    end
  end

  cf_bundle_install(File.expand_path(File.join(node[:cloudfoundry][:path], "services", svc)))
end
