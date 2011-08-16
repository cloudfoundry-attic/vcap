include_attribute "deployment"
default[:redis][:version] = "2.2.4"
default[:redis][:path] = "#{node[:deployment][:home]}/deploy/redis"
default[:redis][:runner] = node[:deployment][:user]
default[:redis][:port] = 6379
default[:redis][:password] = "redis"
default[:redis][:index] = "0"
