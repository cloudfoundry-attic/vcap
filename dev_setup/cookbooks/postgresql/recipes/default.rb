#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#
%w[libpq-dev postgresql].each do |pkg|
  package pkg
end

case node['platform']
when "ubuntu"
  ruby_block "postgresql_conf_update" do
    block do
      / \d*.\d*/ =~ `pg_config --version`
      pg_major_version = $&.strip

      # update postgresql.conf
      postgresql_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "postgresql.conf")
      `grep "^\s*listen_addresses" #{postgresql_conf_file}`
      if $?.exitstatus != 0
        `echo "listen_addresses='#{node[:postgresql][:host]},localhost'" >> #{postgresql_conf_file}`
      else
        `sed -i.bkup -e "s/^\s*listen_addresses.*$/listen_addresses='#{node[:postgresql][:host]},localhost'/" #{postgresql_conf_file}`
      end

      # Cant use service resource as service name needs to be statically defined
      `#{File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")} restart`
    end
  end
else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end
