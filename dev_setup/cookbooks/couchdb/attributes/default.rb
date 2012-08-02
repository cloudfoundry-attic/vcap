include_attribute "deployment"
default[:couchdb][:version] = "1.2.0"
default[:couchdb][:id] = "eyJzaWciOiJTRWNYL1pjTEZGNEZRSHc0bHg0RGFFUkVhMU09Iiwib2lkIjoi%0ANGU0ZTc4YmNhMTFlMTIyMDA0ZTRlOGVjNjQ4NDMxMDUwMTlmMmU3MTkyMzUi%0AfQ==%0A"
default[:couchdb][:path] = File.join(node[:deployment][:home], "deploy", "couchdb")
default[:couchdb][:checksum] = "0f254ddea2471dbc4d3c6cd1fa61e4782c75475fb325024e10f68bf1aa8d5c37"

default[:xulrunner][:version] = "1.9.2.28"

default[:couchdb_gateway][:service][:timeout] = "15"
default[:couchdb_gateway][:node_timeout] = "5"

default[:couchdb_node][:index] = "0"
default[:couchdb_node][:capacity] = "5"
default[:couchdb_node][:token] = "changecouchdbtoken"
default[:couchdb_node][:op_time_limit] = "6"

default[:couchdb][:host] ="127.0.0.1"
default[:couchdb][:port] ="5984"
default[:couchdb][:username] ="admin"
default[:couchdb][:password] ="mysecretpassword"
