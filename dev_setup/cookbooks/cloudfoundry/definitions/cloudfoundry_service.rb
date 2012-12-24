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
  service_name = params[:name]
  # Work around for RabbitMQ service since its directory name is "rabbit"
  service_name = "rabbit" if service_name == "rabbitmq"

  # Work around for vblob/redis/mongo/rabbit since other services haven't wardenized
  if ["vblob", "rabbit", "mongodb", "redis", "mysql", "postgresql"].include?(service_name)
    cf_bundle_install(File.join(node[:cloudfoundry][:path], "services", "ng", service_name))
  else
    cf_bundle_install(File.join(node[:cloudfoundry][:path], "services", service_name))
  end
end
