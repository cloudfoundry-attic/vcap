include_attribute "deployment"
default[:nginx][:worker_connections] = 2048
default[:nginx][:dir] = "/etc/nginx"
default[:nginx][:vcap_log] = "#{node[:deployment][:home]}/sys/log/vcap.access.log"
