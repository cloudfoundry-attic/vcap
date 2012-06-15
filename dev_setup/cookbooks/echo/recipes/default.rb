#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2011, VMware
#
#

bash "Install Echo Server" do
  code <<-EOH
    cd /tmp
    wget #{node[:echo_server][:uri]} -O #{node[:echo_server][:name]} 
    mkdir -p #{node[:echo_server][:path]} 
    mv #{node[:echo_server][:name]}  #{node[:echo_server][:path]}
    cd #{node[:echo_server][:path]}
    nohup java -jar #{node[:echo_server][:name]}  -port #{node[:echo_server][:port]} &
  EOH
  not_if do
    ::File.exists?(File.join(node[:echo_server][:path], node[:echo_server][:name]))
  end
end
