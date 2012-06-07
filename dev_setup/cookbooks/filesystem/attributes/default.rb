include_attribute "deployment"

default[:filesystem_node][:token] = "changefilesystemtoken"
default[:filesystem_gateway][:backends] = ["/var/vcap/store/fss_backend1"]
