#
# Cookbook Name:: uaa
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#

bcrypt = gem_package "bcrypt-ruby" do
  action :nothing
end

bcrypt.run_action(:install)
Gem.clear_paths
require 'bcrypt'

ruby_block "hash secrets" do

  block do
    node[:uaa][:varz][:secret] = BCrypt::Password.create(node[:uaa][:varz][:password])
    node[:uaa][:app][:secret] = BCrypt::Password.create(node[:uaa][:app][:password])
    node[:uaa][:my][:secret] = BCrypt::Password.create(node[:uaa][:my][:password])
    node[:uaa][:scim][:secret] = BCrypt::Password.create(node[:uaa][:scim][:password])
  end

end

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
