#
# Cookbook Name:: cloudfoundry
# Recipe:: default
#
# Copyright 2011, VMWare
#
# All rights reserved - Do Not Redistribute
#

directory node[:cloudfoundry][:path] do
  owner node[:cloudfoundry][:user]
  group node[:cloudfoundry][:user]
  mode "0755"
  action :create
end

git node[:cloudfoundry][:path] do
  repository node[:cloudfoundry][:repo]
  revision node[:cloudfoundry][:revision]
  user node[:cloudfoundry][:user]
  enable_submodules true
  action :sync
end

bash "Bundle install" do
  cwd "#{node[:cloudfoundry][:path]}"
  user "#{node[:cloudfoundry][:user]}"
  environment ({'PATH' => "#{node[:ruby][:path]}/bin:#{ENV['PATH']}"})
  code <<-EOH
  rake bundler:install
  EOH
end

gem_package "vmc" do
  gem_binary "#{node[:ruby][:path]}/bin/gem"
end
