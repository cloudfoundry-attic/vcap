include_attribute "mysql"
include_attribute "postgresql"

default[:service][:mysql][:index] = "0"
default[:service][:mysql][:max_db_size] = "20"
default[:service][:mysql][:host] = "localhost"
default[:service][:mysql][:server_root_password] = node[:mysql][:server_root_password]
default[:service][:mysql][:server_root_user] = node[:mysql][:server_root_user]
default[:service][:mysql][:available_storage] = "1024"

default[:service][:postgresql][:available_storage] = "1024"
default[:service][:postgresql][:index] = "0"
default[:service][:postgresql][:max_db_size] = "20"
default[:service][:postgresql][:host] = "localhost"
default[:service][:postgresql][:server_root_password] = node[:postgresql][:server_root_password]
default[:service][:postgresql][:server_root_user] = node[:postgresql][:server_root_user]
default[:service][:postgresql][:database] = node[:postgresql][:database]

default[:service][:redis][:available_memory] = "4096"
default[:service][:redis][:max_memory] = "16"
default[:service][:redis][:index] = "0"

default[:service][:mongodb][:available_memory] = "4096"
default[:service][:mongodb][:max_memory] = "128"
default[:service][:mongodb][:index] = "0"
