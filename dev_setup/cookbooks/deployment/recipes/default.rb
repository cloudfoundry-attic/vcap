#
# Cookbook Name:: deployment
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:nats_server][:host] ||= cf_local_ip
node[:ccdb][:host] ||= cf_local_ip
node[:postgresql][:host] ||= cf_local_ip

[node[:deployment][:home], File.join(node[:deployment][:home], "deploy"),
 File.join(node[:deployment][:home], "sys", "log"), node[:deployment][:config_path],
 File.join(node[:deployment][:config_path], "staging")].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

var_vcap = File.join("", "var", "vcap")
[var_vcap, File.join(var_vcap, "sys"), File.join(var_vcap, "db"),
 File.join(var_vcap, "data"), File.join(var_vcap, "data", "cloud_controller"),
 File.join(var_vcap, "sys", "log"), File.join(var_vcap, "data", "cloud_controller", "tmp"),
 File.join(var_vcap, "data", "cloud_controller", "staging"),
 File.join(var_vcap, "data", "db"), File.join("", "var", "vcap.local"),
 File.join("", "var", "vcap.local", "staging")].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

template node[:deployment][:info_file] do
  path node[:deployment][:info_file]
  source "deployment_info.json.erb"
  owner node[:deployment][:user]
  mode 0644
  variables({
    :name => node[:deployment][:name],
    :ruby_bin_dir => File.join(node[:ruby][:path], "bin"),
    :cloudfoundry_path => node[:cloudfoundry][:path]
  })
end
