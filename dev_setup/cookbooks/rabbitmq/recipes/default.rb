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

  rabbitmq_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-server-with-plugins-#{node[:rabbitmq][:version_full]}.tar.gz")
  cf_remote_file rabbitmq_tarball_path do
    owner node[:deployment][:user]
    id node[:rabbitmq][:id]
    checksum node[:rabbitmq][:checksum]
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
    tar xzf #{rabbitmq_tarball_path}
    cd rabbitmq_server-#{node[:rabbitmq][:version]}
    cp -rf * #{node[:rabbitmq][:path]}
    EOH
  end

else
  Chef::Log.error("Installation of rabbitmq packages not supported on this platform.")
end
