#
# Cookbook Name:: elasticsearch
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:elasticsearch][:supported_versions].each do |version, install_version|
  #TODO, need more refine to actually support mutiple versions
  Chef::Log.info("Building elasticserarch version: #{version} - #{install_version}")

  elasticsearch_tarball = File.join(node[:deployment][:setup_cache], "elasticsearch-#{install_version}.tar.gz")
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
  mkdir -p #{node[:elasticsearch][:path]}
  tar xzf #{elasticsearch_tarball}
  cp -r elasticsearch-#{install_version}/* #{node[:elasticsearch][:path]}/
  EOH
  end

  bash "Install elasticsearch-http-basic plugin" do
    user node[:deployment][:user]
    code <<-EOH
  mkdir -p #{node[:elasticsearch][:http_basic_plugin][:path]}
  cp #{plugin} #{node[:elasticsearch][:http_basic_plugin][:path]}
  EOH
  end
end
