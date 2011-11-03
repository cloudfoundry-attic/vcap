include_attribute "deployment"
default[:blob][:version] = "1.0"
default[:blob][:path] = File.join(node[:deployment][:home], "deploy", "blob")

default[:blob_node][:index] = "0"
default[:blob_node][:available_memory] = "4096"
default[:blob_node][:max_memory] = "256"
default[:blob_node][:token] = "changeblobtoken"
