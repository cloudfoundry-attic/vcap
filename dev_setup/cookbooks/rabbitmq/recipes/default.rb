#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2011, VMware
#
#

template "rabbitmq_startup.sh" do
   path File.join(node[:warden][:rootfs_path], "usr", "bin", "rabbitmq_startup.sh")
   source "rabbitmq_startup.sh.erb"
   mode 0755
end

rabbitmq_erlang_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-erlang.tar.gz")
cf_remote_file rabbitmq_erlang_tarball_path do
  owner node[:deployment][:user]
  id node[:rabbitmq][:erlang_id]
  checksum node[:rabbitmq][:erlang_checksum]
end

bash "Install Erlang for RabbitMQ" do
  code <<-EOH
  cd #{node[:warden][:rootfs_path]}/var/vcap/packages
  tar xzf #{rabbitmq_erlang_tarball_path}
  EOH
end

node[:rabbitmq][:supported_versions].each do |version, install_version|
  #TODO, need more refine to actually support mutiple versions
  Chef::Log.info("Building rabbitmq version: #{version} - #{install_version}")

  case node['platform']
  when "ubuntu"
    rabbitmq_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-server-with-plugins-#{install_version}.tar.gz")
    cf_remote_file rabbitmq_tarball_path do
      owner node[:deployment][:user]
      id node[:rabbitmq][:id]["#{install_version}"]
      checksum node[:rabbitmq][:checksum]["#{install_version}"]
    end

    bash "Install RabbitMQ" do
      cwd File.join("", "tmp")
      code <<-EOH
      tar xzf #{rabbitmq_tarball_path}
      mkdir -p  #{node[:warden][:rootfs_path]}/var/vcap/packages/rabbitmq/#{version}
      cp -rf rabbitmq/* #{node[:warden][:rootfs_path]}/var/vcap/packages/rabbitmq/#{version}
      EOH
    end

  else
    Chef::Log.error("Installation of rabbitmq packages not supported on this platform.")
  end
end
