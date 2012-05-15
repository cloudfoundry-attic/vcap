module CloudFoundryPostgres

  def cf_pg_reset_user_password(db_sym)
    unless node[db_sym][:adapter] != "postgresql"
      # override the postgresql's user and password
      node[db_sym][:user] = node[:postgresql][:server_root_user]
      node[db_sym][:password] = node[:postgresql][:server_root_password]
    end
  end

  def cf_pg_restart(pg_major_version)
  end

  def cf_pg_update_hba_conf(db, user)
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config" do
        block do
          /\s*\d*.\d*\s*/ =~  "#{node[:postgresql][:version]}"
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
      Chef::Log.error("PostgreSQL config update is not supported on this platform.")
    end
  end

  def cf_pg_setup_db(db, user, passwd, is_super=false)
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
        createdb -p #{node[:postgresql][:server_port]} #{db}
        psql -p #{node[:postgresql][:server_port]} -d #{db} -c \"create role #{user} #{super_val} LOGIN INHERIT CREATEDB\"
        psql -p #{node[:postgresql][:server_port]} -d #{db} -c \"alter role #{user} with password '#{passwd}'\"
        psql -p #{node[:postgresql][:server_port]} -d template1 -c \"create language plpgsql\"
        echo \"db #{db} user #{user} pass #{passwd}\" >> #{File.join("", "tmp", "cf_pg_setup_db")}
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
