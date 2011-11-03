#
# Cookbook Name:: blob
# Recipe:: default
#
# Copyright 2011, VMware
#
#
directory File.join(node[:blob][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Blob" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  cp #{File.join(node[:blob_dir], "blob-src.tgz")} .
  tar xvzf blob-src.tgz
  cd blob-src
  cp -R * #{File.join(node[:blob][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:blob][:path], "bin", "server.js"))
  end
end
