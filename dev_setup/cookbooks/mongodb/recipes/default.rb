#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#

mongodb_tarball_path = File.join(node[:deployment][:setup_cache], "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb][:version]}.tgz")
cf_remote_file mongodb_tarball_path do
  owner node[:deployment][:user]
  source node[:mongodb][:source]
  checksum node[:mongodb][:checksum]
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
  tar xvzf #{mongodb_tarball_path}
  cd mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb][:version]}
  cp #{File.join("bin", "*")} #{File.join(node[:mongodb][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:mongodb][:path], "bin", "mongo"))
  end
end
