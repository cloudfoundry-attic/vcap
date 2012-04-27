# Cookbook Name:: erlang
# Recipe:: default
#
# Copyright 2012, VMware
#
#
%w[ build-essential libncurses5-dev openssl libssl-dev ].each do |pkg|
  package pkg
end

tarball_path = File.join(node[:deployment][:setup_cache], "otp_src_#{node[:erlang][:version]}.tar.gz")
remote_file tarball_path do
  owner node[:deployment][:user]
  source node[:erlang][:source]
  checksum "849d050b59821e9f2831fee2e3267d84b410eee860a55f6fc9320cc00b5205bd"
end

directory node[:erlang][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Erlang" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xvzf #{tarball_path}
  cd otp_src_#{node[:erlang][:version]}
  #{File.join(".", "configure")} --prefix=#{node[:erlang][:path]} --disable-hipe
  make
  make install
  EOH
  not_if do
    ::File.exists?(File.join(node[:erlang][:path], "bin", "erl"))
  end
end
