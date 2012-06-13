include_attribute "deployment"
default[:redis][:version] = "2.2.4"
default[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis")
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"

default[:redis][:id] = "eyJvaWQiOiI0ZTRlNzhiY2EzMWUxMjEwMDRlNGU3ZDUxNDc0NWYwNGYzMDZi%0AMWI3MGQ3YSIsInNpZyI6IjVpb2t6dzFPMzRuRmhiK0x1NEM2bkdWUExtOD0i%0AfQ==%0A"
default[:redis][:checksum] = "6d612b28137c926fb6b668fd85d25862469f9755af4e15f1b37cbe6f88882b32"

default[:redis_node][:capacity] = "200"
default[:redis_node][:index] = "0"
default[:redis_node][:max_memory] = "16"
default[:redis_node][:token] = "changeredistoken"
