#
# Cookbook Name:: stager
# Recipe:: default
#
# Copyright 2012, VMware
#

package "curl"

template node[:stager][:config_file] do
  path File.join(node[:deployment][:config_path], node[:stager][:config_file])
  source "stager.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

template "vcap_redis.conf" do
  path File.join(node[:deployment][:config_path], "vcap_redis.conf")
  source "vcap_redis.conf.erb"
  owner node[:deployment][:user]
  mode 0644
end

template "vcap_redis" do
  path File.join("", "etc", "init.d", "vcap_redis")
  source "vcap_redis.erb"
  owner node[:deployment][:user]
  mode 0755
end

service "vcap_redis" do
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :restart ]
end

cf_bundle_install(File.expand_path("stager", node[:cloudfoundry][:home]))

staging_dir = File.join(node[:deployment][:config_path], "legacy_staging")
node[:stager][:staging].each_pair do |framework, config|
  template config do
    path File.join(staging_dir, config)
    source "#{config}.erb"
    owner node[:deployment][:user]
    mode 0644
  end
end
