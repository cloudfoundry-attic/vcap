include_attribute "deployment"
default[:mvstore][:version] = "1.0"
default[:mvstore][:source] = "lib/mvStore-linux-64.tgz"
default[:mvstore][:path] = File.join(node[:deployment][:home], "deploy", "mvstore")

default[:mvstore_node][:index] = "0"
default[:mvstore_node][:available_memory] = "4096"
default[:mvstore_node][:max_memory] = "128"
default[:mvstore_node][:token] = "changemvstoretoken"
