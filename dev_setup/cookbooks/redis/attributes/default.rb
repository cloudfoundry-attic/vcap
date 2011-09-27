include_attribute "deployment"
default[:redis][:version] = "2.2.4"
default[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis")
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"

default[:redis_node][:index] = "0"
default[:redis_node][:available_memory] = "4096"
default[:redis_node][:max_memory] = "16"
default[:redis_node][:token] = "changeredistoken"
