include_attribute "deployment"
default[:couchdb][:version] = "1.2.0"
default[:couchdb][:source] = "http://mirror.uoregon.edu/apache/couchdb/releases/#{node[:couchdb][:version]}/apache-couchdb-#{node[:couchdb][:version]}.tar.gz"
default[:couchdb][:path] = File.join(node[:deployment][:home], "deploy", "couchdb")
default[:couchdb][:checksum] = "0f254ddea2471dbc4d3c6cd1fa61e4782c75475fb325024e10f68bf1aa8d5c37"

default[:xulrunner][:version] = "1.9.2.28"


default[:couchdb_node][:index] = "0"
default[:couchdb_node][:capacity] = "5"
default[:couchdb_node][:token] = "changecouchdbtoken"

default[:couchdb][:host] ="127.0.0.1"
default[:couchdb][:port] ="5984"
default[:couchdb][:username] ="admin"
default[:couchdb][:password] ="mysecretpassword"
