#
# Cookbook Name:: elasticsearch
# Recipe:: default
#
# Copyright 2011, VMware
#

elasticsearch_tarball = File.join(node[:deployment][:setup_cache], node[:elasticsearch][:distribution_file])
cf_remote_file elasticsearch_tarball do
  owner node[:deployment][:user]
  id node[:elasticsearch][:id]
  checksum node[:elasticsearch][:checksum]
end

plugin = File.join(node[:deployment][:setup_cache], node[:elasticsearch][:http_basic_plugin][:distribution_file])
cf_remote_file plugin do
  owner node[:deployment][:user]
  id node[:elasticsearch][:http_basic_plugin][:id]
  checksum node[:elasticsearch][:http_basic_plugin][:checksum]
end

bash "Install elasticsearch" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  rm -rf #{node[:elasticsearch][:path]}
  tar xzf #{elasticsearch_tarball}
  cp -r #{node[:elasticsearch][:distribution_file].gsub(/.tar.gz/,'')} #{node[:elasticsearch][:path]}
  EOH
end

bash "Install elasticsearch-http-basic plugin" do
  user node[:deployment][:user]
  code <<-EOH
  mkdir -p #{node[:elasticsearch][:http_basic_plugin][:path]}
  cp #{plugin} #{node[:elasticsearch][:http_basic_plugin][:path]}
  EOH
end
