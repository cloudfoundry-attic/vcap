include_attribute "deployment"
default[:mongodb][:version] = "1.8.1"
default[:mongodb][:source] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb[:version]}.tgz"
default[:mongodb][:path] = File.join(node[:deployment][:home], "deploy", "mongodb")

default[:mongodb_node][:capacity] = "50"
default[:mongodb_node][:index] = "0"
default[:mongodb_node][:max_memory] = "128"
default[:mongodb_node][:token] = "changemongodbtoken"
