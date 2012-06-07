#
# Cookbook Name:: vblob
# Recipe:: default
#
# Copyright 2011, VMware
#
#
directory node[:vblob][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  recursive true
  action :create
end

bash "Install vBlob" do
  cwd File.join(node[:node06][:path], "bin")
  user node[:deployment][:user]
  code <<-EOH
  ./node npm -g install express
  ./node npm -g install winston
  ./node npm -g install sax
  ./node npm -g install vows
  cd /tmp
  git clone #{node[:vblob][:source]}
  git reset --hard #{node[:vblob][:commit]}
  cp -r vblob/* #{node[:vblob][:path]}
  rm -rf vblob
  EOH
  not_if do
    ::File.exists?(File.join(node[:vblob][:path], "server.js"))
  end
end
