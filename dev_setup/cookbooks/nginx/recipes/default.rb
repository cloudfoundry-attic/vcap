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

case node['platform']
when "ubuntu"

  case node[:nginx][:router_version]

  # Recipe for v1 router
  when "v1"

    package "nginx"
    template "nginx.conf" do
      path File.join("", "etc", "nginx", "nginx.conf")
      source "ubuntu-nginx.conf.erb"
      owner "root"
      group "root"
      mode 0644
    end

    service "nginx" do
      supports :status => true, :restart => true, :reload => true
      action [ :enable, :start ]
    end

  # Recipe for v2 router
  when "v2"

    %w[ build-essential].each do |pkg|
      package pkg
    end

    # Lua related packages
    remote_file File.join("", "tmp", "lua-#{lua_version}.tar.gz") do
      owner node[:deployment][:user]
      source lua_source
      not_if { ::File.exists?(File.join("", "tmp", "lua-#{lua_version}.tar.gz")) }
    end

    remote_file File.join("", "tmp", "lua-openssl-0.1.1.tar.gz") do
      owner node[:deployment][:user]
      source node[:lua][:openssl_source]
      not_if { ::File.exists?(File.join("", "tmp", "lua-openssl-0.1.1.tar.gz")) }
    end

    remote_file File.join("", "tmp", "lbase64.tar.gz") do
      owner node[:deployment][:user]
      source node[:lua][:base64_source]
      not_if { ::File.exists?(File.join("", "tmp", "lbase64.tar.gz")) }
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

    bash "Install lua openssl" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
      tar xzf lua-openssl-0.1.1.tar.gz
      cd zhaozg-lua-openssl-5ecb647
      sed 's!^PREFIX=.*!PREFIX='#{lua_path}'!' config > tmp
      sed 's!^CC=.*!CC= gcc $(CFLAGS)!' tmp > config
      make
      make install
      EOH
      not_if do
        ::File.exists?(File.join(lua_path, "lib", "lua", "5.1", "openssl.so"))
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
        ::File.exists?(File.join(lua_path, "lib", "lua", "5.1", "cjson.so"))
      end
    end

    bash "Install lua base64" do
      cwd File.join("", "tmp")
      user node[:deployment][:user]
      code <<-EOH
      tar xzf lbase64.tar.gz
      cd base64
      sed 's!^LUAINC=.*!LUAINC='#{lua_path}/include'!' Makefile > tmp
      sed 's!^LUABIN=.*!LUABIN='#{lua_path}/bin'!' tmp > Makefile
      sed 's!^CFLAGS=.*!CFLAGS= $(INCS) $(WARN) -fPIC -O2 $G!' Makefile > tmp
      mv tmp Makefile
      make
      cp base64.so #{lua_path}/lib/lua/5.1
      EOH
      not_if do
        ::File.exists?(File.join(lua_path, "lib", "lua", "5.1", "base64.so"))
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
      LUA_LIB=#{lua_path}/lib LUA_INC=#{lua_path}/include ./configure \
        --prefix=#{nginx_path} \
        --with-pcre=../pcre-8.12 \
        --add-module=../nginx_upload_module-2.2.0 \
        --add-module=../agentzh-headers-more-nginx-module-5fac223 \
        --add-module=../simpl-ngx_devel_kit-bc97eea \
        --add-module=../chaoslawful-lua-nginx-module-4d92cb1
      make
      make install

      # Copy lua library to nginx directory
      cp #{lua_path}/lib/lua/5.1/* #{nginx_path}/sbin

      EOH
      not_if do
        ::File.exists?(File.join(nginx_path, "sbin", "nginx"))
      end
    end

    template "nginx.conf" do
      path File.join(nginx_path, "conf", "nginx.conf")
      source "ubuntu-nginx-uls.conf.erb"
      owner node[:deployment][:user]
      mode 0644
    end

    template "uls.lua" do
      path File.join(nginx_path, "sbin", "uls.lua")
      source "uls.lua.erb"
      owner node[:deployment][:user]
      mode 0644
    end

    template "tablesave.lua" do
      path File.join(nginx_path, "sbin", "tablesave.lua")
      source "tablesave.lua"
      owner node[:deployment][:user]
      mode 0644
    end

    bash "Start nginx" do
      code <<-EOH
      sudo kill `ps -ef | grep nginx | grep -v grep | awk '{print $2}'`
      cd #{nginx_path}/sbin
      ./nginx -c #{nginx_path}/conf/nginx.conf
      EOH
    end

  else
    Chef::Log.error("Router version: #{node[:nginx][:router_version]} is incorrect.")
  end
else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
