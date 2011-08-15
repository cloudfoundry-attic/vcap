#
# Cookbook Name:: cloud_controller
# Recipe:: default
#
# Copyright 2011, VMware
#
#

template node[:cloud_controller][:config_file] do
  path File.join(node[:deployment][:config_path], node[:cloud_controller][:config_file])
  source "cloud_controller.yml.erb"
  owner node[:deployment][:user]
  mode 0644

  builtin_services = []
  case node[:cloud_controller][:builtin_services]
  when Array
    builtin_services = node[:cloud_controller][:builtin_services]
  when Hash
    builtin_services = node[:cloud_controller][:builtin_services].keys
  when String
    builtin_services = node[:cloud_controller][:builtin_services].split(" ")
  else
    Chef::Log.info("Input error: Please specify cloud_controller builtin_services as a list, it has an unsupported type #{node[:cloud_controller][:builtin_services].class}")
    exit 1
  end
  variables({
    :builtin_services => builtin_services
  })
end
cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "cloud_controller")))

staging_dir = File.join(node[:deployment][:config_path], "staging")
node[:cloud_controller][:staging].each_pair do |framework, config|
  template config do
    path File.join(staging_dir, config)
    source "#{config}.erb"
    owner node[:deployment][:user]
    mode 0644
  end
end
