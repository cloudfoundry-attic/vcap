default[:nginx][:worker_connections] = 2048
default[:nginx][:dir] = "/etc/nginx"
default[:nginx][:vcap_log] = "/var/log/nginx/vcap.access.log"
