#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2011, VMware
#
#

case node['platform']
when "ubuntu"

  node[:filesystem_gateway][:backends].each do |path|
    bash "create backends" do
      user node[:deployment][:user]
      code <<-EOH
        mkdir -p #{path}
      EOH
    end
    directory "#{path}" do
      owner node[:deployment][:user]
      group node[:deployment][:user]
      mode "0755"
    end
  end

else
  Chef::Log.error("Installation of filesystem_gateway packages not supported on this platform.")
end
