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

  remote_file File.join("", "tmp", "rabbitmq-server-#{node[:rabbitmq][:version_full]}.tar.gz") do
    owner node[:deployment][:user]
    source node[:rabbitmq][:source]
    not_if { ::File.exists?(File.join("", "tmp", "rabbitmq-server-#{node[:rabbitmq][:version_full]}.tar.gz")) }
  end

  node[:rabbitmq][:plugins].each do |plugin_name|
    remote_file File.join("", "tmp", "#{plugin_name}-#{node[:rabbitmq][:version]}.ez") do
      owner node[:deployment][:user]
      source "#{node[:rabbitmq][:plugins_source]}#{plugin_name}-#{node[:rabbitmq][:version]}.ez"
      not_if { ::File.exists?(File.join("", "tmp", "#{plugin_name}-#{node[:rabbitmq][:version]}.ez")) }
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
    tar xzf rabbitmq-server-#{node[:rabbitmq][:version_full]}.tar.gz
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
      code <<-EOH
      cp -f "#{plugin_name}-#{node[:rabbitmq][:version]}.ez" #{File.join(node[:rabbitmq][:path], "plugins")}
      EOH
      not_if do
        ::File.exists?(File.join(node[:rabbitmq][:path], "plugins", "#{plugin_name}-#{node[:rabbitmq][:version]}.ez"))
      end
    end
  end
else
  Chef::Log.error("Installation of rabbitmq packages not supported on this platform.")
end
