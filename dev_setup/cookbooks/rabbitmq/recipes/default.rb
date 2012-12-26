#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2011, VMware
#
#

directory "#{node[:rabbitmq][:path]}" do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

# install erlang
%w[ build-essential libncurses5-dev openssl libssl-dev ].each do |pkg|
  package pkg
end

rabbitmq_erlang_tarball_path = File.join(node[:deployment][:setup_cache], "rabbitmq-erlang.tar.gz")
cf_remote_file rabbitmq_erlang_tarball_path do
  owner node[:deployment][:user]
  id node[:rabbitmq][:erlang_id]
  checksum node[:rabbitmq][:erlang_checksum]
end

erlang_path = File.join(node[:rabbitmq][:path], "erlang")
directory erlang_path do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  action :create
end

bash "Install Erlang for RabbitMQ" do
  user node[:deployment][:user]
  code <<-EOH
    mkdir -p /tmp/rabbitmq_erlang
    cd /tmp/rabbitmq_erlang
    tar xvzf #{rabbitmq_erlang_tarball_path}
    cd otp_src_R14B01
    ./configure --prefix=#{erlang_path} --disable-hipe
    make
    make install
  EOH
  not_if do
    ::File.exists?(File.join("#{erlang_path}", "bin", "erl"))
  end
end

# install daylimit
daylimit_dir = File.join(node[:rabbitmq][:path], "daylimit")
directory daylimit_dir do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

daylimit_src = File.join(node["cloudfoundry"]["path"], "services", "tools", "daylimit")
bash "install daylimit for RabbitMQ" do
  user node[:deployment][:user]
  code <<-EOH
    git clone -q #{node[:rabbitmq_node][:govendor_repo]} /tmp/govendor

    mkdir -p #{daylimit_dir}/src/daylimit
    cp -rf #{daylimit_src}/* #{daylimit_dir}/src/daylimit
    PATH=#{node[:go][:path]}/bin:$PATH
    export GOROOT=#{node[:go][:path]}
    export GOPATH=#{daylimit_dir}:/tmp/govendor

    cd #{daylimit_dir}/src
    go install daylimit
  EOH
  not_if do
    ::File.exists?(File.join("#{daylimit_dir}", "bin", "daylimit"))
  end
end

template "daylimit.yaml" do
  path File.join(node[:deployment][:config_path], "daylimit.yaml")
  source "daylimit.yaml.erb"
  owner node[:deployment][:user]
  mode 0644
end

template "/etc/init.d/daylimit" do
  path File.join("", "etc", "init.d", "daylimit")
  source "daylimit.erb"
  mode 0755
end

service "daylimit" do
  action [ :restart ]
end

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
        cp -rf rabbitmq_server-#{install_version}/* #{node[:rabbitmq][:path]}/#{version}
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
