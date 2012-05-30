include_attribute "deployment"
default[:redis][:version] = "2.4.14"
default[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis")
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"

default[:redis][:checksum] = "4f26ae8cad0f9143ef30b9bb9565a1618570654eb86ee911c20966971660cc7e"

default[:redis_node][:capacity] = "200"
default[:redis_node][:index] = "0"
default[:redis_node][:max_memory] = "16"
default[:redis_node][:token] = "changeredistoken"
