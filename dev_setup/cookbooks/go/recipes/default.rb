#
# Cookbook Name:: go
# Recipe:: default
#
# Copyright 2011, VMware
#
#

directory node[:go][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

go_package = File.join(node[:deployment][:setup_cache], "go1.0.1.src.tar.gz")
cf_remote_file go_package do
  owner node[:deployment][:user]
  id node[:go][:id]
  checksum node[:go][:checksum]
end

bash "Install golang" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
    tar xzf #{go_package}
    cd go/src
    ./all.bash
    cd ../..
    cp -R go/* #{node[:go][:path]}
  EOH
  not_if do
    ::File.exists?(File.join("#{node[:go][:path]}", "bin", "go"))
  end
end
