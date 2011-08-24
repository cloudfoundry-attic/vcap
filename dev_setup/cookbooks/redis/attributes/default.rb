include_attribute "deployment"
default[:redis][:version] = "2.2.4"
default[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis")
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"
default[:redis][:index] = "0"
default[:redis][:available_memory] = "4096"
default[:redis][:max_memory] = "16"
default[:redis][:token] = "changeredistoken"
