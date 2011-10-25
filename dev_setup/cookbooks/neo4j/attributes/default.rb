default[:neo4j][:version] = "community-1.4.1"
default[:neo4j][:distribution_file] = "neo4j-#{node[:neo4j][:version]}-unix.tar.gz"
default[:neo4j][:service_dir] = "/var/vcap/services/neo4j"
default[:neo4j][:hosting_extension] = "authentication-extension-1.4.jar"

default[:neo4j_node][:index] = "0"
default[:neo4j_node][:available_memory] = "4096"
default[:neo4j_node][:max_memory] = "128"
default[:neo4j_node][:token] = "changeneo4jtoken"
