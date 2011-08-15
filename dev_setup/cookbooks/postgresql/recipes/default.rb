#
# Cookbook Name:: postgres
# Recipe:: default
#
# Copyright 2011, VMware
#
#

%w[libpq-dev postgresql].each do |pkg|
  package pkg
end

bash "Setup PostgreSQL" do
  user "postgres"
  code <<-EOH
  /usr/bin/psql -c "alter role postgres password '#{node[:postgresql][:server_root_password]}'"
  EOH
end
