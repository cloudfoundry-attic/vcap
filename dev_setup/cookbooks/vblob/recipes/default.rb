#
# Cookbook Name:: vblob
# Recipe:: default
#
# Copyright 2011, VMware
#
#

FileUtils.rm_rf(File.join("", "tmp", "vblob"))

directory node[:vblob][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  recursive true
  action :create
end

bash "prepare to install vBlob" do
  cwd File.join(node[:node06][:path], "bin")
  user node[:deployment][:user]
  code <<-EOH
  ./node npm -g install express
  ./node npm -g install winston
  ./node npm -g install sax
  ./node npm -g install vows
  cd /tmp
  git clone #{node[:vblob][:source]}
  EOH
end

node[:vblob][:supported_versions].each do |version|
  bash "install vblob version #{version}" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
    mkdir -p #{File.join(node[:vblob][:path], version)}
    git reset --hard #{node[:vblob][:commit][version]}
    cp -af vblob/* #{File.join(node[:vblob][:path], version)}
    EOH
    not_if do
      ::File.exists?(File.join(node[:vblob][:path], version, "server.js"))
    end
  end
end
