# Cookbook Name:: deployment
# Recipe:: default
#
# Copyright 2012, VMware
# vim: ts=2 sw=2 sts=2 et

node[:nats_server][:host] ||= cf_local_ip
node[:ccdb][:host] ||= cf_local_ip
node[:acmdb][:host] ||= cf_local_ip
node[:uaadb][:host] ||= cf_local_ip
node[:postgresql][:host] ||= cf_local_ip
node[:redis_resque][:host] ||= cf_local_ip
node[:vcap_redis][:host] ||= cf_local_ip
node[:serialization_data_server][:host] ||= cf_local_ip

[
  node[:deployment][:home], File.join(node[:deployment][:home], "deploy"),
  node[:deployment][:log_path], File.join(node[:deployment][:home], "sys", "log"),
  node[:deployment][:config_path],
  File.join(node[:deployment][:config_path], "staging"),
  File.join(node[:deployment][:config_path], "legacy_staging"),
  node[:deployment][:setup_cache],
].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

var_vcap = File.join("", "var", "vcap")
[var_vcap, File.join(var_vcap, "sys"), File.join(var_vcap, "db"), File.join(var_vcap, "services"),
 File.join(var_vcap, "data"), File.join(var_vcap, "data", "cloud_controller"),
 File.join(var_vcap, "sys", "log"), File.join(var_vcap, "sys", "run"),
 File.join(var_vcap, "data", "stager", "tmp"), File.join(var_vcap, "data", "cloud_controller", "tmp"),
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
    :maven_bin_dir => File.join(node[:maven][:path], "bin"),
    :cloudfoundry_home => node[:cloudfoundry][:home],
    :cloudfoundry_path => node[:cloudfoundry][:path],
    :deployment_log_path => node[:deployment][:log_path]
  })
end

file node[:deployment][:local_run_profile] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  content <<-EOH
    export PATH=#{node[:ruby][:path]}/bin:`#{node[:ruby][:path]}/bin/gem env gempath`/bin:#{node[:maven][:path]}/bin:$PATH
    export CLOUD_FOUNDRY_CONFIG_PATH=#{node[:deployment][:config_path]}
  EOH
end
