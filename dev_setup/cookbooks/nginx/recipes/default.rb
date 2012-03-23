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
  lua_tgz = "lua-#{lua_version}.tar.gz"
  lua_dir = "lua-#{lua_version}"
  remote_file File.join("", "tmp", lua_tgz) do
    owner node[:deployment][:user]
    source lua_source
    not_if { ::File.exists?(File.join("", "tmp", lua_tgz)) }
  end

  lua_cjson_tgz = "lua-cjson-1.0.3.tar.gz"
  lua_cjson_dir = "lua-cjson-1.0.3"
  remote_file File.join("", "tmp", lua_cjson_tgz) do
    owner node[:deployment][:user]
    source node[:lua][:cjson_source]
    not_if { ::File.exists?(File.join("", "tmp", lua_cjson_tgz)) }
  end

  # Nginx related packages
  ngx_tgz = "nginx-#{nginx_version}.tar.gz"
  ngx_dir = "nginx-#{nginx_version}"
  remote_file File.join("", "tmp", ngx_tgz) do
    owner node[:deployment][:user]
    source nginx_source
    not_if { ::File.exists?(File.join("", "tmp", ngx_tgz)) }
  end

  pcre_tgz = "pcre-8.21.tar.gz"
  pcre_dir = "pcre-8.21"
  remote_file File.join("", "tmp", pcre_tgz) do
    owner node[:deployment][:user]
    source node[:nginx][:pcre_source]
    not_if { ::File.exists?(File.join("", "tmp", pcre_tgz)) }
  end

  ngx_upload_module_tgz = "nginx_upload_module-2.2.0.tar.gz"
  ngx_upload_module_dir = "nginx_upload_module-2.2.0"
  remote_file File.join("", "tmp", ngx_upload_module_tgz) do
    owner node[:deployment][:user]
    source node[:nginx][:module_upload_source]
    not_if { ::File.exists?(File.join("", "tmp", ngx_upload_module_tgz)) }
  end

  ngx_headers_more_tgz = "headers-more-v0.15rc3.tar.gz"
  ngx_headers_more_dir = "agentzh-headers-more-nginx-module-5fac223"
  remote_file File.join("", "tmp", ngx_headers_more_tgz) do
    owner node[:deployment][:user]
    source node[:nginx][:module_headers_more_source]
    not_if { ::File.exists?(File.join("", "tmp", ngx_headers_more_tgz)) }
  end

  ngx_devel_kit_tgz = "devel-kit-v0.2.17rc2.tar.gz"
  ngx_devel_kit_dir = "simpl-ngx_devel_kit-bc97eea"
  remote_file File.join("", "tmp", ngx_devel_kit_tgz) do
    owner node[:deployment][:user]
    source node[:nginx][:module_devel_kit_source]
    not_if { ::File.exists?(File.join("", "tmp", ngx_devel_kit_tgz)) }
  end

  ngx_lua_tgz = "nginx-lua.v0.4.1.tar.gz"
  ngx_lua_dir = "chaoslawful-lua-nginx-module-204ce2b"
  remote_file File.join("", "tmp", ngx_lua_tgz) do
    owner node[:deployment][:user]
    source node[:nginx][:module_lua_source]
    not_if { ::File.exists?(File.join("", "tmp", ngx_lua_tgz)) }
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
      tar xzf #{lua_tgz}
      cd #{lua_dir}
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
      tar xzf #{lua_cjson_tgz}
      cd #{lua_cjson_dir}
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
      tar xzf #{ngx_tgz}
      tar xzf #{pcre_tgz}
      tar xzf #{ngx_upload_module_tgz}
      tar xzf #{ngx_headers_more_tgz}
      tar xzf #{ngx_devel_kit_tgz}
      tar xzf #{ngx_lua_tgz}
      cd #{ngx_dir}
      LUA_LIB=#{lua_path}/lib LUA_INC=#{lua_path}/include ./configure \
        --prefix=#{nginx_path} \
        --with-pcre=../#{pcre_dir} \
        --add-module=../#{ngx_upload_module_dir} \
        --add-module=../#{ngx_headers_more_dir} \
        --add-module=../#{ngx_devel_kit_dir} \
        --add-module=../#{ngx_lua_dir}
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
