#
# Cookbook Name:: mvstore
# Recipe:: default
#
# Copyright 2011, VMware
#
#

directory File.join(node[:mvstore][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install MVStore" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  cp #{File.join(node[:cloudfoundry][:path], "dev_setup", "lib", "mvStore-linux-64.tgz")} #{File.join(node[:mvstore][:path], "bin")}
  cd #{File.join(node[:mvstore][:path], "bin")}
  tar xvzf mvStore-linux-64.tgz
  EOH
  not_if do
    ::File.exists?(File.join(node[:mvstore][:path], "bin", "mvStore"))
  end
end
