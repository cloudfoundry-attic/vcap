default[:redis][:version] = "2.2.1"
default[:redis][:path] = "/var/lib/redis-#{redis[:version]}"
default[:redis][:runner] = "redis"
default[:redis][:port] = 6379
default[:redis][:password] = "redis"
