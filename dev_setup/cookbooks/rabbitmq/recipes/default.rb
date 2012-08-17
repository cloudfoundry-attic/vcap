#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2011, VMware
#
#

node[:rabbitmq][:supported_versions].each do |version, install_version|
  #TODO, need more refine to actually support mutiple versions
  Chef::Log.info("Building rabbitmq version: #{version} - #{install_version}")

  case node['platform']
  when "ubuntu"
    package "erlang-nox"

    rabbitmq_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-server-with-plugins-generic-unix-#{install_version}.tar.gz")
    cf_remote_file rabbitmq_tarball_path do
      owner node[:deployment][:user]
      id node[:rabbitmq][:id]
      checksum node[:rabbitmq][:checksum]
    end

    directory "#{node[:rabbitmq][:path]}" do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
    end

    bash "Install RabbitMQ" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
    tar xzf #{rabbitmq_tarball_path}
    cd rabbitmq_server-#{install_version}
    cp -rf * #{node[:rabbitmq][:path]}
    EOH
    end

  else
    Chef::Log.error("Installation of rabbitmq packages not supported on this platform.")
  end
end
