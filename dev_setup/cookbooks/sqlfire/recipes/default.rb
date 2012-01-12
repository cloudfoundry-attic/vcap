#
# Cookbook Name:: sqlfire
# Recipe:: default
#
# Copyright 2011, VMware
#
#

directory node[:sqlfire][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:user]
  mode "0755"
  recursive true
  action :create
end

bash "Install SqlFire" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  unzip -o -q #{File.join(node[:sqlfire_dir], "vFabric_SQLFire*.zip")}
  cd vFabric_SQLFire*
  cp -R * #{File.join(node[:sqlfire][:path])}
  EOH
  not_if do
    ::File.exists?(File.join(node[:sqlfire][:path], "bin", "sqlf"))
  end
end
