include_attribute "deployment"
include_attribute "postgresql"

default[:uaadb][:user] = node[:postgresql][:server_root_user]
default[:uaadb][:password] = node[:postgresql][:server_root_password]
default[:uaadb][:database] = "uaa"
default[:uaadb][:port] = "5432"
default[:uaadb][:adapter] = "postgresql"
default[:uaadb][:data_dir] = File.join(node[:deployment][:home], "uaadb_data_dir")
