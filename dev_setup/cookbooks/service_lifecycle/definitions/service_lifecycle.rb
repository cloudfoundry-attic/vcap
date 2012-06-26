# Definition:: service_lifecycle
#
# Copyright 2012, VMware
#

define :service_lifecycle, :service_type => nil do
  if node[:service_lifecycle][:enable] == true && :service_type

    include_recipe "service_lifecycle"
    service_worker_sym = "#{params[:service_type]}_worker".to_sym

    template node[service_worker_sym][:config_file] do
      path File.join(node[:deployment][:config_path], node[service_worker_sym][:config_file])
      source "#{service_worker_sym.to_s}.yml.erb"
      owner node[:deployment][:user]
      mode "0644"
    end

  end

end
