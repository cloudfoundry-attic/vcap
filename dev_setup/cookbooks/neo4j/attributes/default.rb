include_attribute "deployment"
default[:neo4j][:version] = "community-1.4.1"
default[:neo4j][:service_dir] = "/var/vcap/services/neo4j"

default[:neo4j][:server_id] = "eyJvaWQiOiI0ZTRlNzhiY2E1MWUxMjIyMDRlNGU5ODYzZjI4ZjMwNGZkNmMw%0AYTM0MWE1MiIsInNpZyI6Imh0dVhRa3pLd2FxN0dxTC9YZlJKODUwbzJ1VT0i%0AfQ==%0A"
default[:neo4j][:jar_id] = "eyJvaWQiOiI0ZTRlNzhiY2E0MWUxMjEyMDRlNGU4NmVlNTM5MjEwNGZkNmMw%0AYjNjODc4NSIsInNpZyI6ImZrSm5aL1k1THpzaHoxL1hMak9Rb1FHREpSRT0i%0AfQ==%0A"

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
