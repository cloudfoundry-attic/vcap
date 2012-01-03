#
# Cookbook Name:: uaa
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#

gem_package "bcrypt-ruby"

ruby_block "hash secrets" do

  block do
    require 'bcrypt'
    node[:uaa][:varz][:secret] = BCrypt::Password.create(node[:uaa][:varz][:password], :cost=>8)
    node[:uaa][:app][:secret] = BCrypt::Password.create(node[:uaa][:app][:password], :cost=>8)
    node[:uaa][:my][:secret] = BCrypt::Password.create(node[:uaa][:my][:password], :cost=>8)
    node[:uaa][:scim][:secret] = BCrypt::Password.create(node[:uaa][:scim][:password], :cost=>8)
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
  code "mvn install -DskipTests=true"
end
