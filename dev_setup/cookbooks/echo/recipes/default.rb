#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
case node['platform']
when "ubuntu"
  bash "Install Echo Server" do
    code <<-EOH
      cd /tmp
      wget #{node[:echo_server][:uri]} -O #{node[:echo_server][:archive]}
      mkdir -p #{node[:echo_server][:path]}
      unzip #{node[:echo_server][:archive]}
      mv #{node[:echo_server][:name]}  #{node[:echo_server][:path]}
      sudo ln -s -t /etc/init.d/ #{File.join(node[:echo_server][:path], node[:echo_server][:name], 'bin', 'echoserver')}
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
