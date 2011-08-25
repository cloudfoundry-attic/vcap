include_attribute "deployment"
default[:mongodb][:version] = "1.8.1"
default[:mongodb][:source] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb[:version]}.tgz"
default[:mongodb][:path] = File.join(node[:deployment][:home], "deploy", "mongodb")
default[:mongodb][:index] = "0"
default[:mongodb][:available_memory] = "4096"
default[:mongodb][:max_memory] = "128"
default[:mongodb][:token] = "changemongodbtoken"
