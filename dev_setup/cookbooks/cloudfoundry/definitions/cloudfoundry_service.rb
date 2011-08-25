#
# Definitions :: cloudfoundry_service
# Recipe:: default
#
# Copyright 2011, VMware
#
define :cloudfoundry_service do
  params[:components].each do |component|
    template "#{params[:name]}.yml" do
      path File.join(node[:deployment][:config_path], "#{component}.yml")
      source "#{component}.yml.erb"
      owner node[:deployment][:user]
      mode 0644
    end
  end
  cf_bundle_install(File.expand_path(File.join(node[:cloudfoundry][:path], "services", params[:name])))
end
