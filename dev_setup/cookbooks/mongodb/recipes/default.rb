#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
remote_file File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb][:version]}.tgz") do
  owner node[:deployment][:user]
  source node[:mongodb][:source]
  not_if { ::File.exists?(File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb][:version]}.tgz")) }
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
