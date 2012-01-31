#
# Cookbook Name:: acm
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#

gem_package "pg" do
  ignore_failure true
  gem_binary File.join(node[:ruby][:path], "bin", "gem")
end

gem_package "postgres" do
  ignore_failure true
  gem_binary File.join(node[:ruby][:path], "bin", "gem")
end

template "acm.yml" do
  path File.join(node[:deployment][:config_path], "acm.yml")
  source "acm.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "acm")))
