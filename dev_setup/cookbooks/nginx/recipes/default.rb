#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#

# Setup configure flags
node.set[:nginx][:daemon_disable]  = true
node.set[:nginx][:configure_flags] = [
  "--prefix=#{node[:nginx][:prefix]}",
  "--with-pcre=../pcre-8.12",
  "--with-http_ssl_module",
  "--add-module=../headers-more-v0.15rc1",
  "--add-module=../nginx_upload_module-2.2.0"
]

configure_flags = node[:nginx][:configure_flags].join(" ")

nginx_version = node[:nginx][:version]

remote_file "#{Chef::Config[:file_cache_path]}/nginx-#{nginx_version}.tar.gz" do
  source "http://sysoev.ru/nginx/nginx-#{nginx_version}.tar.gz"
  action :create_if_missing
end

cookbook_file "#{Chef::Config[:file_cache_path]}/pcre-8.12.tar.gz" do
  action :create_if_missing
end

cookbook_file "#{Chef::Config[:file_cache_path]}/headers-more-v0.15rc1.tgz" do
  action :create_if_missing
end

cookbook_file "#{Chef::Config[:file_cache_path]}/nginx_upload_module-2.2.0.tar.gz" do
  action :create_if_missing
end

cookbook_file "#{Chef::Config[:file_cache_path]}/upload_module_put_support.patch" do
  action :create_if_missing
end

bash "compile_nginx_source" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    mkdir -p /var/vcap/sys/log/nginx
    mkdir -p /var/vcap/sys/run/nginx

    tar xzf pcre-8.12.tar.gz

    tar xzf headers-more-v0.15rc1.tgz

    tar xzf nginx_upload_module-2.2.0.tar.gz
    cd nginx_upload_module-2.2.0
    patch < ../upload_module_put_support.patch
    cd ..

    tar xzf nginx-#{nginx_version}.tar.gz
    cd nginx-#{nginx_version} && ./configure #{configure_flags}
    make && make install
  EOH
  creates node[:nginx][:src_binary]
end
