#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#

nginx_version = node[:nginx][:version]
nginx_source = node[:nginx][:source]
nginx_path = node[:nginx][:path]
lua_version = node[:lua][:version]
lua_source = node[:lua][:source]
lua_path = node[:lua][:path]
lua_module_path = node[:lua][:module_path]

case node['platform']
when "ubuntu"

  %w[ build-essential].each do |pkg|
    package pkg
  end

  # Lua related packages
  remote_file File.join("", "tmp", "lua-#{lua_version}.tar.gz") do
    owner node[:deployment][:user]
    source lua_source
    not_if { ::File.exists?(File.join("", "tmp", "lua-#{lua_version}.tar.gz")) }
  end

  remote_file File.join("", "tmp", "lua-cjson-1.0.3.tar.gz") do
    owner node[:deployment][:user]
    source node[:lua][:cjson_source]
    not_if { ::File.exists?(File.join("", "tmp", "lua-cjson-1.0.3.tar.gz")) }
  end

  # Nginx related packages
  remote_file File.join("", "tmp", "nginx-#{nginx_version}.tar.gz") do
    owner node[:deployment][:user]
    source nginx_source
    not_if { ::File.exists?(File.join("", "tmp", "nginx-#{nginx_version}.tar.gz")) }
  end

  remote_file File.join("", "tmp", "zero_byte_in_cstr_20120315.patch") do
    owner node[:deployment][:user]
    source node[:nginx][:patch]
    not_if { ::File.exists?(File.join("", "tmp", "zero_byte_in_cstr_20120315.patch")) }
  end

  remote_file File.join("", "tmp", "pcre-8.12.tar.gz") do
    owner node[:deployment][:user]
    source node[:nginx][:pcre_source]
    not_if { ::File.exists?(File.join("", "tmp", "pcre-8.12.tar.gz")) }
  end

  remote_file File.join("", "tmp", "nginx_upload_module-2.2.0.tar.gz") do
    owner node[:deployment][:user]
    source node[:nginx][:module_upload_source]
    not_if { ::File.exists?(File.join("", "tmp", "nginx_upload_module-2.2.0.tar.g")) }
  end

  remote_file File.join("", "tmp", "headers-more-v0.15rc3.tar.gz") do
    owner node[:deployment][:user]
    source node[:nginx][:module_headers_more_source]
    not_if { ::File.exists?(File.join("", "tmp", "headers-more-v0.15rc3.tar.gz")) }
  end

  remote_file File.join("", "tmp", "devel-kit-v0.2.17rc2.tar.gz") do
    owner node[:deployment][:user]
    source node[:nginx][:module_devel_kit_source]
    not_if { ::File.exists?(File.join("", "tmp", "devel-kit-v0.2.17rc2.tar.gz")) }
  end

  remote_file File.join("", "tmp", "nginx-lua.v0.3.1rc24.tar.gz") do
    owner node[:deployment][:user]
    source node[:nginx][:module_lua_source]
    not_if { ::File.exists?(File.join("", "tmp", "nginx-lua.v0.3.1rc24.tar.gz")) }
  end

  directory nginx_path do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  directory lua_path do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  bash "Install lua" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf lua-#{lua_version}.tar.gz
      cd lua-#{lua_version}
      make linux install INSTALL_TOP=#{lua_path}
      EOH
      not_if do
        ::File.exists?(File.join(lua_path, "bin", "lua"))
      end
  end

  bash "Install lua json" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf lua-cjson-1.0.3.tar.gz
      cd lua-cjson-1.0.3
      sed 's!^PREFIX ?=.*!PREFIX ?='#{lua_path}'!' Makefile > tmp
      mv tmp Makefile
      make
      make install
    EOH
    not_if do
      ::File.exists?(File.join(lua_module_path, "cjson.so"))
    end
  end

  bash "Install nginx" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf nginx-#{nginx_version}.tar.gz
      tar xzf pcre-8.12.tar.gz
      tar xzf nginx_upload_module-2.2.0.tar.gz
      tar xzf headers-more-v0.15rc3.tar.gz
      tar xzf devel-kit-v0.2.17rc2.tar.gz
      tar xzf nginx-lua.v0.3.1rc24.tar.gz
      cd nginx-#{nginx_version}

      patch -p0 < ../zero_byte_in_cstr_20120315.patch

      LUA_LIB=#{lua_path}/lib LUA_INC=#{lua_path}/include ./configure \
        --prefix=#{nginx_path} \
        --with-pcre=../pcre-8.12 \
        --add-module=../nginx_upload_module-2.2.0 \
        --add-module=../agentzh-headers-more-nginx-module-5fac223 \
        --add-module=../simpl-ngx_devel_kit-bc97eea \
        --add-module=../chaoslawful-lua-nginx-module-4d92cb1
      make
      make install

      EOH
  end

  template "nginx.conf" do
    path File.join(nginx_path, "conf", "nginx.conf")
    source "ubuntu-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "uls.lua" do
    path File.join(lua_module_path, "uls.lua")
    source File.join(node[:lua][:plugin_source_path], "uls.lua")
    local true
    owner node[:deployment][:user]
    mode 0644
  end

  template "tablesave.lua" do
    path File.join(lua_module_path, "tablesave.lua")
    source File.join(node[:lua][:plugin_source_path], "tablesave.lua")
    local true
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx" do
    path File.join("", "etc", "init.d", "nginx")
    source "nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

  bash "Stop running nginx" do
    code <<-EOH
      pid=`ps -ef | grep nginx | grep -v grep | awk '{print $2}'`
      [ ! -z "$pid" ] && sudo kill $pid || true
    EOH
  end

  service "nginx" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
