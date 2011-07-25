default[:mongodb][:version]           = "1.8.1"
default[:mongodb][:source]            = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb[:version]}.tgz"
default[:mongodb][:path] = "/var/vcap/deploy/mongodb"
