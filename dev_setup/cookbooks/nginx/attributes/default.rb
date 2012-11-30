include_attribute "deployment"

default[:nginx][:version] = "0.8.54"
default[:nginx][:id]  = "eyJzaWciOiJYaGxvTGFpVktXR3B6MExZVDBBdFNod3RDdzg9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIyMjA0ZTRlOTg2MzkyNmIxMDUwMThmMmNiNGFiNjki%0AfQ==%0A"
default[:nginx][:patch_id] = "eyJzaWciOiJkVGp2bjEyMXZYT0VWUHFUQjhrdjZ3Zk56WHc9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIyMDA0ZTRlOGVjNmI0NGI2MDUwMThmM2JmMGMzOTQi%0AfQ==%0A"
default[:nginx][:pcre_id]  = "eyJzaWciOiJidU8zVW4rMEE5SVpYdkIxakpTb1NmNkV4N0k9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIyMDA0ZTRlOGVjNjQ4NDMxMDUwMThmNDFjMDA1NWMi%0AfQ==%0A"
default[:nginx][:module_upload_id]  = "eyJzaWciOiJNU2VoeXVtVTZabDQxaHNLT2xLTFhka2hpTVU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDUwMThmMmU0YWYzNTUi%0AfQ==%0A"
default[:nginx][:module_headers_more_id]  = "eyJzaWciOiJHNmZUd092Wk03MTBIdWZGbTZsdVhlUkkvQkk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMjFlMTIxMDA0ZTRlN2Q1MTFmNTUzMDUwMThmM2I2YTEzMGQi%0AfQ==%0A"
default[:nginx][:module_devel_kit_id]  = "eyJzaWciOiJPZ0dPL3BBbmszOS96MWYvWFNadm11bGZDNFk9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMDA0ZTRlOGVjNjg0MDc3MDUwMThmM2FkYmExZmMi%0AfQ==%0A"
default[:nginx][:module_lua_id]  = "eyJzaWciOiIrODdSUXRTbUFINm5Sd3NNcFc2YlFDSVNPUXM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIyMDA0ZTRlOGVjNjg0MDc3MDUwMThmMmQ2ZGVhZTci%0AfQ==%0A"
default[:nginx][:upload_module_patch_id] = "eyJzaWciOiJSR3o1Z2JqZW9LZ2Vacjc3MW0wMyt2REhnSW89Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDUwYWQ4Yjg1OTM2NTgi%0AfQ==%0A"
default[:nginx][:path]    = File.join(node[:deployment][:home], "deploy", "nginx", "nginx-#{nginx[:version]}")
default[:nginx][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log")
default[:nginx][:checksums][:source] = "12e28efb9a54452fa6e579e08ce7c864e49d6ea6104cc2b3de5a4416ead90593"
default[:nginx][:checksums][:patch] = "0d4b26aab43fce6f1cdd1f2d0c578b82b14af9497366c99018f97479df20fceb"
default[:nginx][:checksums][:pcre_source] = "710d506ceb98305b2bd26ba93725acba03f8673765aba5a5598110cac7dbf5c3"
default[:nginx][:checksums][:module_upload_source] = "b1c26abe0427180602e257627b4ed21848c93cc20cefc33af084983767d65805"
default[:nginx][:checksums][:module_headers_more_source] = "10587007913805a5193e3104e81fd180a5c52bf7c3f5a5746081660916619bde"
default[:nginx][:checksums][:module_devel_kit_source] = "bf5540d76d1867b4411091f16c6c786fd66759099c59483c76c68434020fdb02"
default[:nginx][:checksums][:module_lua_source] = "249042d34a44dddd0ab06a37066fc9a09b692cef5f317d5e86f18d838bb0323f"
default[:nginx][:checksums][:upload_module_patch] = "fe3d14b255a129e81d58223fcf3c5f3bfc31f2d8b0f6e6b6e3a15fb71975b7ad"

default[:lua][:version] = "5.1.4"
default[:lua][:simple_version] = lua[:version].match(/\d+\.\d+/).to_s # something like 5.1
default[:lua][:id]  = "eyJzaWciOiJrd0YvTVVmV24zb3pscHFHN0cwcXhQZ2RjV3c9Iiwib2lkIjoi%0ANGU0ZTc4YmNhMzFlMTIyMjA0ZTRlOTg2M2IxYjc0MDUwMThmMjUzMTUyNzQi%0AfQ==%0A"
default[:lua][:path]    = File.join(node[:deployment][:home], "deploy", "lua", "lua-#{lua[:version]}")
default[:lua][:cjson_id]  = "eyJzaWciOiJ5OGp2YWlvUWptNXhrc3hTODdYQ0x0N0JXemM9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNjFlMTIxMjA0ZTRlODZlZWJlNTkxMDUwMThmMjViZGE3MDYi%0AfQ==%0A"
default[:lua][:module_path]    = File.join(lua[:path], 'lib', 'lua', lua[:simple_version])
default[:lua][:plugin_source_path] = File.join(node["cloudfoundry"]["path"], "router", "ext", "nginx")
default[:lua][:checksums][:source] = "b038e225eaf2a5b57c9bcc35cd13aa8c6c8288ef493d52970c9545074098af3a"
default[:lua][:checksums][:cjson_source] = "9659fef3d4d3bc08b3fbd7827636dad6fb236c83d277b632879cb354f1b2e942"

default[:nginx][:worker_connections] = 2048
default[:nginx][:uls_ip] = "localhost"
default[:nginx][:uls_port] = 8081
default[:nginx][:log_home] = File.join(node[:deployment][:home], "log", "nginx")
default[:nginx][:status_user] = "admin"
default[:nginx][:status_passwd] = "password"

default[:router][:session_key]    = "14fbc303b76bacd1e0a3ab641c11d11400341c5d"
default[:router][:trace_key]    = "222"
