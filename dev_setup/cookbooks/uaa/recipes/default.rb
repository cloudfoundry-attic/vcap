#
# Cookbook Name:: uaa
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#

unless node[:uaadb][:adapter] != "postgresql"
  # override the postgresql's user and password
  node[:uaadb][:user] = node[:postgresql][:server_root_user]
  node[:uaadb][:password] = node[:postgresql][:server_root_password]
end

unless node[:ccdb][:adapter] != "postgresql"
  # override the postgresql's user and password
  node[:ccdb][:user] = node[:postgresql][:server_root_user]
  node[:ccdb][:password] = node[:postgresql][:server_root_password]
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
  code "#{node[:maven][:path]}/bin/mvn install -U -DskipTests=true"
end
