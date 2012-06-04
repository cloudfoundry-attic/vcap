#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"
  package "erlang-nox"

  rabbitmq_server_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-server-#{node[:rabbitmq][:version_full]}.tar.gz")
  cf_remote_file rabbitmq_server_tarball_path do
    owner node[:deployment][:user]
    source node[:rabbitmq][:source]
    checksum node[:rabbitmq][:checksums][:rabbitmq_server]
  end

  node[:rabbitmq][:plugins].each do |plugin_name|
    cf_remote_file File.join(node[:deployment][:setup_cache], "#{plugin_name}-#{node[:rabbitmq][:version]}.ez") do
      owner node[:deployment][:user]
      source "#{node[:rabbitmq][:plugins_source]}#{plugin_name}-#{node[:rabbitmq][:version]}.ez"
      checksum node[:rabbitmq][:checksums][:plugins][plugin_name.gsub("-", "_").to_sym]
    end
  end

  directory "#{node[:rabbitmq][:path]}" do
    owner node[:deployment][:user]
    group node[:deployment][:user]
    mode "0755"
  end

  bash "Install RabbitMQ" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
    tar xzf "#{rabbitmq_server_tarball_path}"
    cd rabbitmq_server-#{node[:rabbitmq][:version]}
    cp -rf * #{node[:rabbitmq][:path]}
    EOH
    not_if do
      ::File.exists?(File.join(node[:rabbitmq][:path], "sbin", "rabbitmq-server"))
    end
  end

  node[:rabbitmq][:plugins].each do |plugin_name|
    bash "Install RabbitMQ #{plugin_name} plugin" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      plugin_ez_path = File.join(node[:deployment][:setup_cache], "#{plugin_name}-#{node[:rabbitmq][:version]}.ez")
      code <<-EOH
      cp -f "#{plugin_ez_path}" #{File.join(node[:rabbitmq][:path], "plugins")}
      EOH
      not_if do
        ::File.exists?(File.join(node[:rabbitmq][:path], "plugins", "#{plugin_name}-#{node[:rabbitmq][:version]}.ez"))
      end
    end
  end
else
  Chef::Log.error("Installation of rabbitmq packages not supported on this platform.")
end
