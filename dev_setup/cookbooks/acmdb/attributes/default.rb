include_attribute "postgresql"
default[:acmdb][:user] = "root"
default[:acmdb][:password] = "changeme"
default[:acmdb][:database] = "acm"
default[:acmdb][:port] = "5432"
default[:acmdb][:adapter] = "postgresql"
default[:acmdb][:data_dir] = File.join(node[:deployment][:home], "acmdb_data_dir")
