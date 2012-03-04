include_attribute "deployment"
include_attribute "postgresql"
default[:uaadb][:user] = "root"
default[:uaadb][:password] = "changeme"
default[:uaadb][:database] = "uaa"
default[:uaadb][:port] = "5432"
default[:uaadb][:adapter] = "postgresql"
default[:uaadb][:data_dir] = File.join(node[:deployment][:home], "uaadb_data_dir")
