include_attribute "deployment"
default[:sqlfire][:version] = "1.0"
default[:sqlfire][:path] = File.join(node[:deployment][:home], "deploy", "sqlfire")

default[:sqlfire_node][:index] = "0"
default[:sqlfire_node][:available_memory] = "4096"
default[:sqlfire_node][:max_memory] = "256"
default[:sqlfire_node][:token] = "changesqlfiretoken"
