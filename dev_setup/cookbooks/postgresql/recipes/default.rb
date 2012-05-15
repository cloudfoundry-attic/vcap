#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#

case node['platform']
when "ubuntu"

  %w[python-software-properties postgresql-common postgresql-client-common libpq-dev].each do |pkg|
    package pkg
  end

  ruby_block "postgresql_install_config" do
    block do
      /\s*\d*.\d*\s*/ =~ "#{node[:postgresql][:version]}"
      pg_major_version = $&.strip
      # install postgresql server & client
      `add-apt-repository ppa:pitti/postgresql`
      `apt-get update`
      postgresql_client_pkg = "postgresql-client-#{pg_major_version}"
      postgresql_pkg = "postgresql-#{pg_major_version}"
      `apt-get install -y #{postgresql_client_pkg} #{postgresql_pkg}`

      # update postgresql.conf
      postgresql_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "postgresql.conf")
      `grep "^\s*listen_addresses" #{postgresql_conf_file}`
      if $?.exitstatus != 0
        `echo "listen_addresses='#{node[:postgresql][:host]},localhost'" >> #{postgresql_conf_file}`
      else
        `sed -i.bkup -e "s/^\s*listen_addresses.*$/listen_addresses='#{node[:postgresql][:host]},localhost'/" #{postgresql_conf_file}`
      end

      `grep "^\s*port\s*=\s*\d*" #{postgresql_conf_file}`
      if $?.exitstatus != 0
        `echo "port = #{node[:postgresql][:server_port]}" >> #{postgresql_conf_file}`
      else
        `sed -i.bkup -e "s/^\s*port\s*=\s*.*/port = #{node[:postgresql][:server_port]}/" #{postgresql_conf_file}`
      end

      # restart postgrsql
      init_file = "#{File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")}"
      backup_init_file = "#{File.join("", "etc", "init.d", "postgresql")}"

      if File.exists?(init_file)
        Chef::Log.error("Fail to restart postgresql using #{init_file}") unless system("#{init_file} restart")
      else
        if File.exists?(backup_init_file)
          Chef::Log.error("Fail to restart postgresql using #{backup_init_file}") unless system("#{backup_init_file} restart #{pg_major_version}")
        else
          Chef::Log.error("Installation of PostgreSQL maybe failed, could not find init script")
        end
      end
    end
  end
else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end



