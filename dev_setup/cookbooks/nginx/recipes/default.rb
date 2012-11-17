#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#

nginx_version = node[:nginx][:version]
nginx_path = node[:nginx][:path]
lua_version = node[:lua][:version]
lua_path = node[:lua][:path]
lua_module_path = node[:lua][:module_path]

case node['platform']
when "ubuntu"

  %w[ build-essential].each do |pkg|
    package pkg
  end

  # Lua related packages
  lua_tarball = File.join(node[:deployment][:setup_cache], "lua-#{lua_version}.tar.gz")
  cf_remote_file lua_tarball do
    owner node[:deployment][:user]
    id node[:lua][:id]
    checksum node[:lua][:checksums][:source]
  end

  lua_cjson_tarball = File.join(node[:deployment][:setup_cache], "lua-cjson-1.0.3.tar.gz")
  cf_remote_file lua_cjson_tarball do
    owner node[:deployment][:user]
    id node[:lua][:cjson_id]
    checksum node[:lua][:checksums][:cjson_source]
  end

  # Nginx related packages
  nginx_tarball = File.join(node[:deployment][:setup_cache], "nginx-#{nginx_version}.tar.gz")
  cf_remote_file nginx_tarball do
    owner node[:deployment][:user]
    id node[:nginx][:id]
    checksum node[:nginx][:checksums][:source]
  end

  nginx_patch = File.join(node[:deployment][:setup_cache], "zero_byte_in_cstr_20120315.patch")
  cf_remote_file nginx_patch do
    owner node[:deployment][:user]
    id node[:nginx][:patch_id]
    checksum node[:nginx][:checksums][:patch]
  end

  pcre_tarball = File.join(node[:deployment][:setup_cache], "pcre-8.12.tar.gz")
  cf_remote_file pcre_tarball do
    owner node[:deployment][:user]
    id node[:nginx][:pcre_id]
    checksum node[:nginx][:checksums][:pcre_source]
  end

  nginx_upload_module_tarball = File.join(node[:deployment][:setup_cache], "nginx_upload_module-2.2.0.tar.gz")
  cf_remote_file nginx_upload_module_tarball do
    owner node[:deployment][:user]
    id node[:nginx][:module_upload_id]
    checksum node[:nginx][:checksums][:module_upload_source]
  end

  headers_more_tarball = File.join(node[:deployment][:setup_cache], "headers-more-v0.15rc1.tar.gz")
  cf_remote_file headers_more_tarball do
    owner node[:deployment][:user]
    id node[:nginx][:module_headers_more_id]
    checksum node[:nginx][:checksums][:module_headers_more_source]
  end

  devel_kit_tarball = File.join(node[:deployment][:setup_cache], "devel-kit-v0.2.17rc2.tar.gz")
  cf_remote_file devel_kit_tarball do
    owner node[:deployment][:user]
    id node[:nginx][:module_devel_kit_id]
    checksum node[:nginx][:checksums][:module_devel_kit_source]
  end

  nginx_lua_tarball = File.join(node[:deployment][:setup_cache], "nginx-lua.v0.3.1rc24.tar.gz")
  cf_remote_file nginx_lua_tarball do
    owner node[:deployment][:user]
    id node[:nginx][:module_lua_id]
    checksum node[:nginx][:checksums][:module_lua_source]
  end

  directory nginx_path do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end

  directory node[:nginx][:log_home] do
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
      tar xzf #{lua_tarball}
      cd lua-#{lua_version}
      make linux install INSTALL_TOP=#{lua_path}
    EOH
  end

  bash "Install lua json" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf #{lua_cjson_tarball}
      cd lua-cjson-1.0.3
      sed 's!^PREFIX ?=.*!PREFIX ?='#{lua_path}'!' Makefile > tmp
      mv tmp Makefile
      make
      make install
    EOH
  end

  bash "Install nginx" do
    cwd File.join("", "tmp")
    user node[:deployment][:user]
    code <<-EOH
      tar xzf #{nginx_tarball}
      tar xzf #{pcre_tarball}
      tar xzf #{nginx_upload_module_tarball}
      tar xzf #{headers_more_tarball}
      tar xzf #{devel_kit_tarball}
      tar xzf #{nginx_lua_tarball}

      cd nginx-#{nginx_version}
      patch -p0 < #{nginx_patch}

      LUA_LIB=#{lua_path}/lib LUA_INC=#{lua_path}/include ./configure \
        --prefix=#{nginx_path} \
        --with-http_ssl_module \
        --with-pcre=../pcre-8.12 \
        --with-cc-opt=-Wno-unused-but-set-variable \
        --add-module=../nginx_upload_module-2.2.0 \
        --add-module=../headers-more-v0.15rc1 \
        --add-module=../simpl-ngx_devel_kit-bc97eea \
        --add-module=../chaoslawful-lua-nginx-module-4d92cb1

      make
      make install
    EOH
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

  template "nginx_router.conf" do
    path File.join(nginx_path, "conf", "nginx_router.conf")
    source "router-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_router" do
    path File.join("", "etc", "init.d", "nginx_router")
    source "router-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

  template "nginx_cc.conf" do
    path File.join(nginx_path, "conf", "nginx_cc.conf")
    source "cc-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_cc" do
    path File.join("", "etc", "init.d", "nginx_cc")
    source "cc-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

  template "nginx_sds.conf" do
    path File.join(nginx_path, "conf", "nginx_sds.conf")
    source "sds-nginx.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  template "nginx_sds" do
    path File.join("", "etc", "init.d", "nginx_sds")
    source "sds-nginx.erb"
    owner node[:deployment][:user]
    mode 0755
  end

  bash "Stop running nginx" do
    code <<-EOH
      pid=`ps -ef | grep nginx | grep -v grep | awk '{print $2}'`
      [ ! -z "$pid" ] && sudo kill $pid || true
    EOH
  end

  service "nginx_router" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

  service "nginx_cc" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

  service "nginx_sds" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :restart ]
  end

else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
