include_attribute "deployment"

default[:filesystem_node][:token] = "changefilesystemtoken"

default[:filesystem_gateway][:service][:timeout] = "15"
default[:filesystem_gateway][:node_timeout] = "10"
default[:filesystem_gateway][:backends] = ["/var/vcap/store/fss_backend1"]
