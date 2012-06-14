module CloudFoundryPostgres

  def cf_pg_check_port(pg_major_version, pg_port)
    # check the process listening on the port
    process_pid = `sudo lsof -i:#{pg_port} | grep LISTEN | head -n 1 | awk '{print $1,$2}'`.strip
    return if process_pid == ""
    # no process listening on the port
    name, pid = process_pid.split
    Chef::Log.error("The port is not occupied by postgresql database, but #{name} pid #{pid}") && (exit 1) unless name == "postgres"
    binary = `ps -fp #{pid} | awk '{print $8}' | tail -n1`.strip
    return if binary == ""
    version_check = `#{binary} --version | grep postgres | grep #{pg_major_version}`.strip
    Chef::Log.error("The running postgresql listening on port #{pg_port} could not match the version: #{pg_major_version}, try another port") && (exit 1) if version_check == ""
  end

  def cf_pg_install(pg_major_version, pg_port)
    # check the port
    cf_pg_check_port(pg_major_version, pg_port)

    # install postgresql server & client
    `apt-get install -y python-software-properties`
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
      `echo "port = #{pg_port}" >> #{postgresql_conf_file}`
    else
      `sed -i.bkup -e "s/^\s*port\s*=\s*.*/port = #{pg_port}/" #{postgresql_conf_file}`
    end

    # restart postgrsql
    init_file = "#{File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")}"
    backup_init_file = "#{File.join("", "etc", "init.d", "postgresql")}"

    if File.exists?(init_file)
      Chef::Log.error("Fail to restart postgresql using #{init_file}") && (exit 1) unless system("#{init_file} restart")
    else
      if File.exists?(backup_init_file)
        Chef::Log.error("Fail to restart postgresql using #{backup_init_file}") && (exit 1) unless system("#{backup_init_file} restart #{pg_major_version}")
      else
        Chef::Log.error("Installation of PostgreSQL maybe failed, could not find init script")
        exit 1
      end
    end
  end

  def cf_pg_reset_user_password(db_sym)
    if node[db_sym][:adapter] == "postgresql" && node[:postgresql][:system_version] == node[:postgresql][:service_version] && node[:postgresql][:system_port] == node[:postgresql][:service_port]
      # override the postgresql's user and password
      node[db_sym][:user] = node[:postgresql][:server_root_user]
      node[db_sym][:password] = node[:postgresql][:server_root_password]
    end
  end

  def cf_pg_update_hba_conf(db, user, pg_version)
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config" do
        block do
          /\s*\d*.\d*\s*/ =~  "#{pg_version}"
          pg_major_version = $&.strip

          # Update pg_hba.conf
          pg_hba_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "pg_hba.conf")
          `grep "#{db}\s*#{user}" #{pg_hba_conf_file}`
          if $?.exitstatus != 0
            `echo "host #{db} #{user} 0.0.0.0/0 md5" >> #{pg_hba_conf_file}`
          end

          # restart postgrsql
          init_file = "#{File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")}"
          backup_init_file = "#{File.join("", "etc", "init.d", "postgresql")}"

          if File.exists?(init_file)
            Chef::Log.error("Fail to restart postgresql using #{init_file}") && (exit 1) unless system("#{init_file} restart")
          else
            if File.exists?(backup_init_file)
              Chef::Log.error("Fail to restart postgresql using #{backup_init_file}") && (exit 1) unless system("#{backup_init_file} restart #{pg_major_version}")
            else
              Chef::Log.error("Installation of PostgreSQL maybe failed, could not find init script")
              exit 1
            end
          end
        end
      end
    else
      Chef::Log.error("PostgreSQL config update is not supported on this platform.")
    end
  end

  def cf_pg_setup_db(db, user, passwd, is_super=false, server_port="5432")
    case node['platform']
    when "ubuntu"
      if is_super
        super_val="SUPERUSER"
      else
        super_val="NOSUPERUSER"
      end
      bash "Setup PostgreSQL database #{db}" do
        user "postgres"
        code <<-EOH
        createdb -p #{server_port} #{db}
        psql -p #{server_port} -d #{db} -c \"create role #{user} #{super_val} LOGIN INHERIT CREATEDB\"
        psql -p #{server_port} -d #{db} -c \"alter role #{user} with password '#{passwd}'\"
        psql -p #{server_port} -d template1 -c \"create language plpgsql\"
        echo \"db #{db} user #{user} pass #{passwd} on port #{server_port}\" >> #{File.join("", "tmp", "cf_pg_setup_db")}
        EOH
      end
    else
      Chef::Log.error("PostgreSQL database setup is not supported on this platform.")
    end
  end
end

class Chef::Recipe
  include CloudFoundryPostgres
end
