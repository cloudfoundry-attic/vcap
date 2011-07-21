#
# Cookbook Name:: postgres
# Recipe:: default
#
# Copyright 2011, VMware
#
# All rights reserved - Do Not Redistribute
#

%w[postgresql libpq-dev].each do |p|
  package p
end

bash "Setup PostgreSQL" do
  user "postgres"
  code <<-EOH
  /usr/bin/psql -c "alter role postgres password '#{node[:postgres][:server_password]}'"
  EOH
end
