include_attribute "deployment"

default[:nginx][:version] = "0.8.54"
default[:nginx][:source]  = "http://nginx.org/download/nginx-#{nginx[:version]}.tar.gz"
default[:nginx][:patch] = "http://nginx.org/download/patch.2012.memory.txt"
default[:nginx][:pcre_source]  = "http://sourceforge.net/projects/pcre/files/pcre/8.12/pcre-8.12.tar.gz"
default[:nginx][:module_upload_source]  = "http://www.grid.net.ru/nginx/download/nginx_upload_module-2.2.0.tar.gz"
default[:nginx][:module_headers_more_source]  = "https://github.com/agentzh/headers-more-nginx-module/tarball/v0.15rc3"
default[:nginx][:module_devel_kit_source]  = "https://github.com/simpl/ngx_devel_kit/tarball/v0.2.17rc2"
default[:nginx][:module_lua_source]  = "https://github.com/chaoslawful/lua-nginx-module/tarball/v0.3.1rc24"
default[:nginx][:path]    = File.join(node[:deployment][:home], "deploy", "nginx", "nginx-#{nginx[:version]}")
default[:nginx][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log")

default[:lua][:version] = "5.1.4"
default[:lua][:simple_version] = lua[:version].match(/\d+\.\d+/).to_s # something like 5.1
default[:lua][:source]  = "http://www.lua.org/ftp/lua-#{lua[:version]}.tar.gz"
default[:lua][:path]    = File.join(node[:deployment][:home], "deploy", "lua", "lua-#{lua[:version]}")
default[:lua][:cjson_source]  = "http://www.kyne.com.au/~mark/software/lua-cjson-1.0.3.tar.gz"
default[:lua][:module_path]    = File.join(lua[:path], 'lib', 'lua', lua[:simple_version])
default[:lua][:plugin_source_path] = File.join(node["cloudfoundry"]["path"], "router", "ext", "nginx")

default[:nginx][:worker_connections] = 2048
default[:nginx][:uls_ip] = "localhost"
default[:nginx][:uls_port] = 8081
default[:nginx][:log_home] = File.join(node[:deployment][:home], "log")
default[:nginx][:status_user] = "admin"
default[:nginx][:status_passwd] = "password"

default[:router][:session_key]    = "14fbc303b76bacd1e0a3ab641c11d11400341c5d"
default[:router][:trace_key]    = "222"
