#
# Cookbook Name:: services
# Recipe:: default
#
# Copyright 2011, VMware
#
node[:service_components].each do |component|
  template "#{component}.yml" do
    path File.join(node[:deployment][:config_path], "#{component}.yml")
    source "#{component}.yml.erb"
    owner node[:deployment][:user]
    mode 0644
  end
end

node[:services].each do |service|
  cf_bundle_install(File.expand_path(File.join(node[:cloudfoundry][:path], "services", service)))
end
