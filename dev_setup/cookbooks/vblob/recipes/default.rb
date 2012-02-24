#
# Cookbook Name:: vblob
# Recipe:: default
#
# Copyright 2011, VMware
#
#
directory File.join(node[:vblob][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install vBlob" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  cp #{File.join(node[:vblob_dir], "vblob-src.tgz")} .
  tar xvzf vblob-src.tgz
  cd vblob-src
  cp -R * #{File.join(node[:vblob][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:vblob][:path], "bin", "server.js"))
  end
end
