#
# Cookbook Name:: mssql
# Recipe:: default
#
#
#

case node['platform']
when "ubuntu"

  service "mssql" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
  end
else
  Chef::Log.error("Installation of mssql not supported on this platform.")
end
