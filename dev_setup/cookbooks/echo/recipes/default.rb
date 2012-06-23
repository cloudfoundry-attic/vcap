#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
case node['platform']
when "ubuntu"
  echoserver_tarball_path = File.join(node[:deployment][:setup_cache], "echoserver.zip")
  cf_remote_file echoserver_tarball_path do
    owner node[:deployment][:user]
    id node[:echo_server][:id]
    checksum node[:echo_server][:checksum]
  end

  directory node[:echo_server][:path] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  bash "Install Echo Server" do
    code <<-EOH
      unzip #{echoserver_tarball_path}
      mv echoserver #{File.join(node[:deployment][:home], 'deploy')}
      ln -s -t /etc/init.d/ #{File.join(node[:echo_server][:path], 'bin', 'echoserver')}
    EOH
    not_if do
      ::File.exists?(File.join('', 'etc', 'init.d', 'echoserver'))
    end
  end

  service "echoserver" do
    supports :status => true, :restart => true
    action [ :enable, :start ]
  end
else
  Chef::Log.error("Installation of echo server not supported on this platform.")
end
