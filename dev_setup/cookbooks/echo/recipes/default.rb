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

  bash "Install Echo Server" do
    code <<-EOH
      unzip #{echoserver_tarball_path} -d /tmp
      cp -r /tmp/echoserver #{File.join(node[:deployment][:home], 'deploy')}
      ln -s -t /etc/init.d/ #{File.join(node[:echo_server][:path], 'bin', 'echoserver')}
    EOH
    not_if do
      ::File.exists?(File.join(node[:echo_server][:path], 'bin', 'echoserver'))
    end
  end

  template File.join(node[:echo_server][:path], 'conf', 'wrapper.conf') do
    source "wrapper.conf.erb"
    owner "root"
    group "root"
    mode "0600"
    notifies :restart, "service[echoserver]"
  end

  service "echoserver" do
    supports :status => true, :restart => true
    action [ :enable, :start ]
  end
else
  Chef::Log.error("Installation of echo server not supported on this platform.")
end
