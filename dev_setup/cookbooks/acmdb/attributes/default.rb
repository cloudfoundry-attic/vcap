include_attribute "deployment"
include_attribute "postgresql"

default[:acmdb][:user] = node[:postgresql][:server_root_user]
default[:acmdb][:password] = node[:postgresql][:server_root_password]
default[:acmdb][:database] = "acm"
default[:acmdb][:port] = node[:postgresql][:system_port]
default[:acmdb][:adapter] = "postgresql"
default[:acmdb][:data_dir] = File.join(node[:deployment][:home], "acmdb_data_dir")
