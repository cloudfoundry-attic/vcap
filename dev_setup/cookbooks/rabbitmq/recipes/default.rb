#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2011, VMware
#
#

# install erlang
directory "#{node[:rabbitmq][:path]}" do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

rabbitmq_erlang_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-erlang.tar.gz")
cf_remote_file rabbitmq_erlang_tarball_path do
  owner node[:deployment][:user]
  id node[:rabbitmq][:erlang_id]
  checksum node[:rabbitmq][:erlang_checksum]
end

bash "Install Erlang for RabbitMQ" do
  user node[:deployment][:user]
  code <<-EOH
    cd #{node[:rabbitmq][:path]}
    tar xzf #{rabbitmq_erlang_tarball_path}
  EOH
end

# install daylimit
daylimit_dir = File.join(node[:rabbitmq][:path], "daylimit_ng")
directory daylimit_dir do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

daylimit_src = File.join(node["cloudfoundry"]["path"], "services", "tools", "daylimit_ng")
bash "install daylimit_ng for RabbitMQ" do
  user node[:deployment][:user]
  code <<-EOH
    git clone -q #{node[:rabbitmq_node][:govendor_repo]} /tmp/govendor

    mkdir -p #{daylimit_dir}/src/daylimit_ng
    cp -rf #{daylimit_src}/* #{daylimit_dir}/src/daylimit_ng
    PATH=#{node[:go][:path]}/bin:$PATH
    export GOROOT=#{node[:go][:path]}
    export GOPATH=#{daylimit_dir}:/tmp/govendor

    cd #{daylimit_dir}/src
    go install daylimit_ng
  EOH
  not_if do
    ::File.exists?(File.join("#{daylimit_dir}", "bin", "daylimit_ng"))
  end
end

# service daylimit_ng start
#template "daylimit_ng.conf" do
#  path File.join(node[:deployment][:config_path], "daylimit_ng.conf")
#  source "daylimit_ng.conf.erb"
#  owner node[:deployment][:user]
#  mode 0644
#end

#template "/etc/init.d/daylimit_ng" do
#  path File.join("", "etc", "init.d", "daylimit_ng")
#  source "daylimit_ng.erb"
#  mode 0755
#end

#service "daylimit_ng" do
#  supports :status => true, :restart => true, :reload => true
#  action [ :enable, :restart ]
#end

# install rabbitmq
node[:rabbitmq][:supported_versions].each do |version, install_version|
  #TODO, need more refine to actually support mutiple versions
  Chef::Log.info("Building rabbitmq version: #{version} - #{install_version}")

  case node['platform']
  when "ubuntu"
    source_file_id, source_file_checksum = id_and_checksum_for_rabbitmq_version(install_version)
    rabbitmq_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-server-with-plugins-#{install_version}.tar.gz")
    cf_remote_file rabbitmq_tarball_path do
      owner node[:deployment][:user]
      id source_file_id
      checksum source_file_checksum
    end

    bash "Install RabbitMQ #{install_version} As #{version}" do
      cwd File.join("", "tmp")
      code <<-EOH
        tar xzf #{rabbitmq_tarball_path}
        mkdir -p #{node[:rabbitmq][:path]}/#{version}
        cp -rf rabbitmq/* #{node[:rabbitmq][:path]}/#{version}
      EOH
    end

  else
    Chef::Log.error("Installation of rabbitmq packages not supported on this platform.")
  end
end

bin_dir = File.join(node[:rabbitmq][:path], "common", "bin")
directory bin_dir do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install rabbitmq tools" do
  user node[:deployment][:user]
  code <<-EOH
    cp #{node[:service][:common_path]}/utils.sh #{bin_dir}
  EOH
end

template File.join(bin_dir, "warden_service_ctl") do
   source "warden_service_ctl.erb"
   mode 0755
end
