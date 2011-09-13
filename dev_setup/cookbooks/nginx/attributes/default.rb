include_attribute "deployment"

# Build info
default[:nginx][:version] = "0.8.54"
default[:nginx][:prefix] = "/var/vcap/packages/nginx"

# Configuration
#default[:nginx][:worker_connections] = 2048
#default[:nginx][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log")
