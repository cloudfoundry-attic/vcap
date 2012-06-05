include_attribute "node::node06"
default[:vblob][:source] = "https://github.com/cloudfoundry/vblob.git"
default[:vblob][:path] = "/var/vcap/packages/vblob"
default[:vblob][:commit] = "ec432e6ebaf8b25c2ad900bbbee642f096fef93b"

default[:vblob_gateway][:service][:timeout] = "15"
default[:vblob_gateway][:node_timeout] = "10"

default[:vblob_node][:capacity] = "200"
default[:vblob_node][:index] = "0"
default[:vblob_node][:token] = "changevblobtoken"
default[:vblob_node][:max_memory] = "128"
default[:vblob_node][:auth] = "disabled"
default[:vblob_node][:op_time_limit] = "6"
