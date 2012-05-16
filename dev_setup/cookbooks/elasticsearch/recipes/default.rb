#
# Cookbook Name:: elasticsearch
# Recipe:: default
#
# Copyright 2011, VMware
#

remote_file File.join("", "tmp", node[:elasticsearch][:distribution_file]) do
  owner node[:deployment][:user]
  source node[:elasticsearch][:distribution_url]
  checksum node[:elasticsearch][:checksum]
  not_if do
    ::File.exists?(File.join(node[:elasticsearch][:path], "bin", "elasticsearch"))
  end
end

remote_file File.join("", "tmp", node[:elasticsearch][:http_basic_plugin][:distribution_file]) do
  owner node[:deployment][:user]
  source node[:elasticsearch][:http_basic_plugin][:distribution_url]
  checksum node[:elasticsearch][:http_basic_plugin][:checksum]
  not_if do
    ::File.exists?(File.join(node[:elasticsearch][:http_basic_plugin][:path], node[:elasticsearch][:http_basic_plugin][:distribution_file]))
  end
end

bash "Install elasticsearch" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xzf #{node[:elasticsearch][:distribution_file]}
  mv #{node[:elasticsearch][:distribution_file].gsub(/.tar.gz/,'')} #{node[:elasticsearch][:path]}
  EOH
  not_if do
    ::File.exists?(File.join(node[:elasticsearch][:path], "bin", "elasticsearch"))
  end
end

bash "Install elasticsearch-http-basic plugin" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  mkdir -p #{node[:elasticsearch][:http_basic_plugin][:path]}
  mv #{node[:elasticsearch][:http_basic_plugin][:distribution_file]} #{node[:elasticsearch][:http_basic_plugin][:path]}
  EOH
  not_if do
    ::File.exists?(File.join(node[:elasticsearch][:http_basic_plugin][:path], node[:elasticsearch][:http_basic_plugin][:distribution_file]))
  end
end
