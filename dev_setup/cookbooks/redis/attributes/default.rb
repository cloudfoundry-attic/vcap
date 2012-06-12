include_attribute "deployment"
default[:redis][:version] = "2.2.15"
default[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis")
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"

default[:redis][:checksum] = "4143b7fab809c5fe586265b4f792f346206a3a8082bbf79f70081a0538bab3cb"

default[:redis_node][:capacity] = "200"
default[:redis_node][:index] = "0"
default[:redis_node][:max_memory] = "16"
default[:redis_node][:token] = "changeredistoken"
