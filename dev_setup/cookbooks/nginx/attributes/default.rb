include_attribute "deployment"
default[:nginx][:worker_connections] = 2048
default[:nginx][:dir] = File.join("", "etc", "nginx")
default[:nginx][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log")
