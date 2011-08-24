module CloudFoundryPostgres
  def cf_pg_update_hba_conf(db, user)
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config" do
        block do
          / \d*.\d*/ =~ `pg_config --version`
          pg_major_version = $&.strip

          # Update pg_hba.conf
          pg_hba_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "pg_hba.conf")
          `grep "#{db}\s*#{user}" #{pg_hba_conf_file}`
          if $?.exitstatus != 0
            `echo "host #{db} #{user} 0.0.0.0/0 md5" >> #{pg_hba_conf_file}`
          end
          # Cant use service resource as service name needs to be statically defined
          `#{File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")} restart`
        end
      end
    else
      Chef::Log.error("PostgreSQL config update is not supported on this platform.")
    end
  end

  def cf_pg_setup_db(db, user, passwd)
    case node['platform']
    when "ubuntu"
      bash "Setup PostgreSQL database #{db}" do
        user "postgres"
        code <<-EOH
        createdb #{db}
        psql -d #{db} -c \"create role #{user} NOSUPERUSER LOGIN INHERIT CREATEDB\"
        psql -d #{db} -c \"alter role #{user} with password '#{passwd}'\"
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
