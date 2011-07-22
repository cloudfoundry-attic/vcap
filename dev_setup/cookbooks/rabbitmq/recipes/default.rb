#
# Cookbook Name:: rabbitmq-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"
  package "erlang-nox"

  remote_file "/tmp/rabbitmq-server_#{node[:rabbitmq][:version_full]}.deb" do
    source node[:rabbitmq][:source]
    not_if { ::File.exists?("/tmp/rabbitmq-server_#{node[:rabbitmq][:version_full]}.deb") }
  end

  bash "Install RabbitMQ" do
    cwd "/tmp"
    code <<-EOH
    dpkg -i rabbitmq-server_#{node[:rabbitmq][:version_full]}.deb
    EOH
    not_if do
      ::File.exists?("/usr/sbin/rabbitmq-server")
    end
  end
else
  Chef::Log.error("Installation of rabbitmq packages not supported on this platform.")
end
