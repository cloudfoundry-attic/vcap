include_attribute "deployment"
default[:vblob][:version] = "1.0"
default[:vblob][:path] = File.join(node[:deployment][:home], "deploy", "vblob")

default[:vblob_node][:index] = "0"
default[:vblob_node][:available_memory] = "4096"
default[:vblob_node][:max_memory] = "256"
default[:vblob_node][:token] = "changevblobtoken"
