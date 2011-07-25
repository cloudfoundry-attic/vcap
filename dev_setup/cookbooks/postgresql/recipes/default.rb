#
# Cookbook Name:: postgres
# Recipe:: default
#
# Copyright 2011, VMware
#
#

%w[postgresql libpq-dev].each do |pkg|
  package pkg
end

bash "Setup PostgreSQL" do
  user "postgres"
  code <<-EOH
  /usr/bin/psql -c "alter role postgres password '#{node[:postgres][:server_root_password]}'"
  EOH
end
