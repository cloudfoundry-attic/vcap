# Definition:: service_backup
#
# Copyright 2011, VMware
#

define :service_backup, :service_type => "mysql" do
  if node[:backup][:enable] == true

    include_recipe "backup"
    service_backup_sym = "#{params[:service_type]}_backup".to_sym

    template node[service_backup_sym][:config_file] do
      path File.join(node[:deployment][:config_path], node[service_backup_sym][:config_file])
      source "#{service_backup_sym.to_s}.yml.erb"
      owner node[:deployment][:user]
      mode "0644"
    end

    template node[service_backup_sym][:cron_file] do
      path File.join(node[:deployment][:config_path], node[service_backup_sym][:cron_file])
      source "#{service_backup_sym.to_s}.cron.erb"
      owner node[:deployment][:user]
      mode "0644"
    end

  end

end

