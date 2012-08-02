include_attribute "deployment"
default[:neo4j][:version] = "community-1.4.1"
default[:neo4j][:service_dir] = "/var/vcap/services/neo4j"

default[:neo4j][:server_id] = "eyJzaWciOiJ1aENFMlpLVm1qU2JVaVdzSmtadXhJV0F5Y1E9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNDFlMTIyMDA0ZTRlOGVjNjVmNjdmMDUwMWEwYTc5ZGZjNjYi%0AfQ==%0A"
default[:neo4j][:jar_id] = "eyJzaWciOiJMRURKclNvOTNHWWo1dzBjNngrelZFVFZvSkU9Iiwib2lkIjoi%0ANGU0ZTc4YmNhNTFlMTIxMDA0ZTRlN2Q1MTkwNmNkMDUwMWEwYTg1N2IyMjUi%0AfQ==%0A"

default[:neo4j][:checksum][:server] = "bf1d5fd477cf8dde8718b2dcced0d74293702083b66b1278fe84284503dd3ce8"
default[:neo4j][:checksum][:jar] = "37cdfcc91490f1aaf0fd58dc6591e08c1c6c3044348c76a594dbcaeedbdbdbcd"

default[:neo4j_gateway][:service][:timeout] = "15"
default[:neo4j_gateway][:node_timeout] = "10"

default[:neo4j_node][:capacity] = "200"
default[:neo4j_node][:index] = "0"
default[:neo4j_node][:available_memory] = "4096"
default[:neo4j_node][:max_memory] = "128"
default[:neo4j_node][:token] = "changeneo4jtoken"
default[:neo4j_node][:op_time_limit] = "6"
