#
# Cookbook Name:: erlang
# Recipe:: default
#
# Copyright 2011, VMware
#
#
%w[ build-essential libncurses5-dev openssl libssl-dev ].each do |pkg|
  package pkg
end

remote_file "/tmp/otp_src_#{node[:erlang][:version]}.tar.gz" do
  owner node[:deployment][:user]
  source node[:erlang][:source]
  not_if { ::File.exists?("/tmp/otp_src_#{node[:erlang][:version]}.tar.gz") }
end

directory node[:erlang][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Erlang" do
  cwd "/tmp"
  user node[:deployment][:user]
  code <<-EOH
  tar xvzf otp_src_#{node[:erlang][:version]}.tar.gz
  cd otp_src_#{node[:erlang][:version]}
  ./configure --prefix=#{node[:erlang][:path]}
  make
  make install
  EOH
  not_if do
    ::File.exists?("#{node[:erlang][:path]}/bin/erl")
  end
end
