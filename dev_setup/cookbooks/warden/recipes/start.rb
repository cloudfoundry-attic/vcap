#
# Cookbook Name:: warden
# Recipe:: default
#
# Copyright 2012, VMware
#

bash "Restart warden server" do
  code <<-EOH
    /etc/init.d/warden_server restart
  EOH
end
