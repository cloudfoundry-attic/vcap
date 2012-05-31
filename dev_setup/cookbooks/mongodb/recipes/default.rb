#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#

cf_remote_file File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb][:version]}.tgz") do
  owner node[:deployment][:user]
  source node[:mongodb][:source]
  checksum '0a84e0c749604cc5d523a8d8040beb0633ef8413ecd9e85b10190a30c568bb37'
end

directory File.join(node[:mongodb][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Mongodb" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xvzf mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb][:version]}.tgz
  cd mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb][:version]}
  cp #{File.join("bin", "*")} #{File.join(node[:mongodb][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:mongodb][:path], "bin", "mongo"))
  end
end
