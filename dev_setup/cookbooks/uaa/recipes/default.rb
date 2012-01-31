#
# Cookbook Name:: uaa
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#

template "uaa.yml" do
  path File.join(node[:deployment][:config_path], "uaa.yml")
  source "uaa.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

bash "Grab dependencies for UAA" do
  user node[:deployment][:user]
  not_if "[ -d ~/.m2/repository/org/cloudfoundry/runtime ]"
  cwd "#{node[:cloudfoundry][:path]}/uaa"
  code "mvn install -U -DskipTests=true"
end
