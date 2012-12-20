#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#

goyaml_package = File.join(node[:deployment][:setup_cache], "goyaml.068c0b7271.src.tar.gz")
cf_remote_file goyaml_package do
  owner node[:deployment][:user]
  id node[:mongodb_proxy][:id][:yaml]
  checksum node[:mongodb_proxy][:checksum][:yaml]
end

log4go_package = File.join(node[:deployment][:setup_cache], "log4go.1fa5d16681.src.tar.gz")
cf_remote_file log4go_package do
  owner node[:deployment][:user]
  id node[:mongodb_proxy][:id][:log4]
  checksum node[:mongodb_proxy][:checksum][:log4]
end

mgo_package = File.join(node[:deployment][:setup_cache], "mgo.57414de697.src.tar.gz")
cf_remote_file mgo_package do
  owner node[:deployment][:user]
  id node[:mongodb_proxy][:id][:mgo]
  checksum node[:mongodb_proxy][:checksum][:mgo]
end

directory node[:mongodb_proxy][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

proxy_path = File.join(node["cloudfoundry"]["path"], "services", "tools", "mongodb_proxy")
bash "install mongodb proxy" do
  user node[:deployment][:user]
  code <<-EOH
    cp -r #{proxy_path}/* #{node[:mongodb_proxy][:path]}
    cp #{goyaml_package} #{node[:mongodb_proxy][:path]}/src
    cp #{log4go_package} #{node[:mongodb_proxy][:path]}/src
    cp #{mgo_package} #{node[:mongodb_proxy][:path]}/src
    PATH=#{node[:go][:path]}/bin:$PATH
    export GOROOT=#{node[:go][:path]}
    export GOPATH=#{node[:mongodb_proxy][:path]}

    cd #{node[:mongodb_proxy][:path]}/src
    tar zxf goyaml.068c0b7271.src.tar.gz
    tar zxf log4go.1fa5d16681.src.tar.gz
    tar zxf mgo.57414de697.src.tar.gz

    go install proxyctl
  EOH
  not_if do
    ::File.exists?(File.join("#{node[:mongodb_proxy][:path]}", "bin", "proxyctl"))
  end
end

directory node[:mongodb][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

node[:mongodb][:supported_versions].each do |version, install_version|
  Chef::Log.info("Building Mongo Version: #{version} - #{install_version}")

  install_path = File.join(node[:mongodb][:path], "#{version}")
  source_file_id, source_file_checksum = id_and_checksum_for_version(install_version)

  mongodb_tarball_path = File.join(node[:deployment][:setup_cache], "mongodb-linux-#{install_version}.tgz")

  cf_remote_file mongodb_tarball_path do
    owner node[:deployment][:user]
    id source_file_id
    checksum source_file_checksum
  end

  directory File.join(install_path) do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  bash "Install Mongodb #{version} (#{install_version})" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xvzf #{mongodb_tarball_path}
      mkdir -p "#{install_path}/bin"
      cp -r mongodb-linux-x86_64-#{install_version}/bin/* #{install_path}/bin
    EOH
    not_if do
      ::File.exists?(File.join(install_path, "bin", "mongo"))
    end
  end
end

directory File.join(node[:mongodb][:path], "common", "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

directory File.join(node[:mongodb][:path], "common", "config") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "install mongodb tools" do
  user node[:deployment][:user]
  code <<-EOH
    cp #{node[:service][:common_path]}/utils.sh #{node[:mongodb][:path]}/common/bin
  EOH
end

template File.join(node[:mongodb][:path], "common", "bin", "warden_service_ctl") do
   source "warden_service_ctl.erb"
   mode 0755
end

template File.join(node[:mongodb][:path], "common", "config", "mongodb_proxy.yml") do
   source "mongodb_proxy.yml.erb"
   mode 0755
end

template File.join(node[:mongodb][:path], "common", "config", "mongodb.conf") do
   source "mongodb.conf.erb"
   mode 0644
end
