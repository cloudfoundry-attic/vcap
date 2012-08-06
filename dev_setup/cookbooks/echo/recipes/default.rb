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
      if [ -L "/etc/init.d/echoserver" ]; then
        service echoserver stop
        rm /etc/init.d/echoserver
      fi
      if [ -d "/tmp/echoserver/" ]; then
        rm -rf /tmp/echoserver/
      fi
      if [ -d #{File.join(node[:echo_server][:path])} ]; then
        rm -rf #{File.join(node[:echo_server][:path])}
      fi

      unzip #{echoserver_tarball_path} -d /tmp
      cp -r /tmp/echoserver #{File.join(node[:deployment][:home], 'deploy')}
      ln -s -t /etc/init.d/ #{File.join(node[:echo_server][:path], 'echoserver')}
    EOH
    not_if do
      ::File.exists?(File.join(node[:echo_server][:path], 'echoserver'))
    end
  end

  template File.join(node[:echo_server][:path], 'echoserver') do
    source "echoserver.erb"
    owner "root"
    group "root"
    mode "0755"
  end

  service "echoserver" do
    supports :status => true, :restart => true
    action [ :enable, :restart ]
  end
else
  Chef::Log.error("Installation of echo server not supported on this platform.")
end
