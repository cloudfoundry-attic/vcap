#
# Cookbook Name:: cloudfoundry
# Recipe:: default
#
# Copyright 2011, VMWare
#
#

directory node[:cloudfoundry][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  action :create
  not_if { node[:cloudfoundry][:revision].nil? }
end

git node[:cloudfoundry][:path] do
  repository node[:cloudfoundry][:repo]
  revision node[:cloudfoundry][:revision]
  user node[:deployment][:user]
  enable_submodules true
  action :sync
  not_if { node[:cloudfoundry][:revision].nil? }
end

# Gem packages have transient failures, so try once while ignoring failures
gem_package "vmc" do
  ignore_failure true
  gem_binary "#{node[:ruby][:path]}/bin/gem"
end

# Do not ignore failures
gem_package "vmc" do
  gem_binary "#{node[:ruby][:path]}/bin/gem"
end
