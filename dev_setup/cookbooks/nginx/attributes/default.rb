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
default[:nginx][:checksums][:source] = "12e28efb9a54452fa6e579e08ce7c864e49d6ea6104cc2b3de5a4416ead90593"
default[:nginx][:checksums][:patch] = "0d4b26aab43fce6f1cdd1f2d0c578b82b14af9497366c99018f97479df20fceb"
default[:nginx][:checksums][:pcre_source] = "710d506ceb98305b2bd26ba93725acba03f8673765aba5a5598110cac7dbf5c3"
default[:nginx][:checksums][:module_upload_source] = "b1c26abe0427180602e257627b4ed21848c93cc20cefc33af084983767d65805"
default[:nginx][:checksums][:module_headers_more_source] = "7f4e229127bc7c5afa88db9531b1778571de58b2f36a0b24c8a69fcfbaa13de5"
default[:nginx][:checksums][:module_devel_kit_source] = "bf5540d76d1867b4411091f16c6c786fd66759099c59483c76c68434020fdb02"
default[:nginx][:checksums][:module_lua_source] = "249042d34a44dddd0ab06a37066fc9a09b692cef5f317d5e86f18d838bb0323f"

default[:lua][:version] = "5.1.4"
default[:lua][:simple_version] = lua[:version].match(/\d+\.\d+/).to_s # something like 5.1
default[:lua][:source]  = "http://www.lua.org/ftp/lua-#{lua[:version]}.tar.gz"
default[:lua][:path]    = File.join(node[:deployment][:home], "deploy", "lua", "lua-#{lua[:version]}")
default[:lua][:cjson_source]  = "http://github.com/mpx/lua-cjson/tarball/ddbb686f535accac1e3cc375994191883fbe35d8"
default[:lua][:module_path]    = File.join(lua[:path], 'lib', 'lua', lua[:simple_version])
default[:lua][:plugin_source_path] = File.join(node["cloudfoundry"]["path"], "router", "ext", "nginx")
default[:lua][:checksums][:source] = "b038e225eaf2a5b57c9bcc35cd13aa8c6c8288ef493d52970c9545074098af3a"
default[:lua][:checksums][:cjson_source] = "b4e3495dde10d087a9550d3a6f364e8998a5dda4f5f4722c69ff89420c9a8c09"

default[:nginx][:worker_connections] = 2048
default[:nginx][:uls_ip] = "localhost"
default[:nginx][:uls_port] = 8081
default[:nginx][:log_home] = File.join(node[:deployment][:home], "log")
default[:nginx][:status_user] = "admin"
default[:nginx][:status_passwd] = "password"

default[:router][:session_key]    = "14fbc303b76bacd1e0a3ab641c11d11400341c5d"
default[:router][:trace_key]    = "222"
