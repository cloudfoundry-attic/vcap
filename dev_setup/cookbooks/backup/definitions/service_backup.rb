# Definition:: service_backup
#
# Copyright 2011, VMware
#

define :service_backup, :service_type => "mysql" do
  include_recipe "backup"
  service_backup_sym = "#{params[:service_type]}_backup".to_sym
  template node[service_backup_sym][:config_file] do
    path File.join(node[:deployment][:config_path], node[service_backup_sym][:config_file])
    source "#{service_backup_sym.to_s}.yml.erb"
    owner node[:deployment][:user]
    mode "0755"
  end

  template node[service_backup_sym][:cron_file] do
    path File.join(node[:deployment][:config_path], node[service_backup_sym][:cron_file])
    source "#{service_backup_sym.to_s}.cron.erb"
    owner node[:deployment][:user]
    mode "0755"
  end

  bash "add_to_crontab" do
    user "#{node[:deployment][:user]}"
    code <<-EOH
    (crontab -l | sed /#{service_backup_sym.to_s}/d; cat #{File.join(node[:deployment][:config_path], node[service_backup_sym][:cron_file])}) | sed /^$/d | crontab
    EOH
  end
end

